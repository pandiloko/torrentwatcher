# Torrent / Transmission helpers. Populates associative array TW_TORRENT_FIELDS per torrent id.

declare -gA TW_TORRENT_FIELDS

list_completed_torrent_ids() {
    transmission-remote -l | sed -e '1d;$d' | grep "100%" | tr -s ' ' | cut -f2 -d ' ' | grep -Eo '[0-9]+'
}

extract_info() {
    local id=$1 restore=
    [[ $(echo "$-") =~ .*x.* ]] && set +x && restore=yes
    TW_TORRENT_FIELDS=()
    local oIFS key value line
    oIFS=$IFS
    IFS=$'\n'
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" != *:* ]] && continue
        key="${line%%:*}"
        key=$(trim "$key")
        key=${key// /_}
        key=${key,,}
        value="${line#*:}"
        value=$(trim "$value")
        TW_TORRENT_FIELDS[$key]=$value
    done < <(transmission-remote -t "$id" -i | grep ":")
    IFS=$oIFS
    [[ $restore == "yes" ]] && set -x
}

_add_torrents_from_watch() {
    local watch_dir=$1 incoming_dir=$2 label=$3
    local i
    for i in "${watch_dir}"/*.torrent; do
        [ -e "$i" ] || continue
        logger "Adding torrents ($label): $i"
        transmission-remote -a "$i" -w "$incoming_dir" >>"$LOGFILE" 2>&1 && mv "$i" "$i.added"
    done
}

add_torrents() {
    transmission-remote -w "$INCOMING_ROOT_FOLDER" >>"$LOGFILE" 2>&1
    _add_torrents_from_watch "$WATCH_MOVIES_FOLDER" "$INCOMING_MOVIES_FOLDER" "movies"
    _add_torrents_from_watch "$WATCH_TVSHOWS_FOLDER" "$INCOMING_TVSHOWS_FOLDER" "tvshows"
    _add_torrents_from_watch "$WATCH_ANIME_FOLDER" "$INCOMING_ANIME_FOLDER" "anime"
    _add_torrents_from_watch "$WATCH_OTHER_FOLDER" "$INCOMING_OTHER_FOLDER" "other"

    if [ -e "${WATCH_OTHER_FOLDER}/magnet.txt" ]; then
        logger "Processing magnet file"
        (
            while IFS='' read -r i || [[ -n "$i" ]]; do
                transmission-remote -a "$i" -w "$INCOMING_OTHER_FOLDER" >>"$LOGFILE" 2>&1 && echo "$i" >>"${WATCH_OTHER_FOLDER}/magnet.txt.added"
            done <"${WATCH_OTHER_FOLDER}/magnet.txt"
        )
        rm -f "${WATCH_OTHER_FOLDER}/magnet.txt"
    fi
}

process_torrent() {
    local ret=1337
    local th="${TW_TORRENT_FIELDS[hash]}"
    cp "$ROOT_FOLDER/log/amc-exclude.txt" "$ROOT_FOLDER/log/amc-exclude.txt.previous"

    if [ -d "${TW_TORRENT_FIELDS[location]}/${TW_TORRENT_FIELDS[name]}" ]; then
        if [ ! -f "/tmp/filebot-$th.log" ]; then
            filebot_command copy "${TW_TORRENT_FIELDS[location]}/${TW_TORRENT_FIELDS[name]}" &>"/tmp/filebot-$th.log"
            ret=$?
        fi
    elif [ -f "${TW_TORRENT_FIELDS[location]}/${TW_TORRENT_FIELDS[name]}" ]; then
        filebot_command copy "${TW_TORRENT_FIELDS[location]}" &>"/tmp/filebot-$th.log"
        ret=$?
    fi

    case $ret in
        1337)
            logger "already processed"
            ret=0
            ;;
        4)
            logger "file already exists"
            ret=0
            ;;
        100)
            logger "no valid file found"
            ret=0
            ;;
        0)
            logger "file found and copied"
            ret=0
            ;;
        3)
            logger "recoverable error??"
            rm -f "/tmp/filebot-$th.log"
            mv "$ROOT_FOLDER/log/amc-exclude.txt.previous" "$ROOT_FOLDER/log/amc-exclude.txt"
            ret=1
            ;;
        *)
            ret=1
            ;;
    esac
    return $ret
}

process_torrent_queue() {
    local id state time_spent th
    for id in $(list_completed_torrent_ids); do
        extract_info "$id"
        [[ "${TW_TORRENT_FIELDS[location]}" -ef "$INCOMING_ANIME_FOLDER" ]] && FILEBOT_LABEL="ut_label=anime"
        [[ "${TW_TORRENT_FIELDS[location]}" -ef "$INCOMING_MOVIES_FOLDER" ]] && FILEBOT_LABEL="ut_label=movie"
        [[ "${TW_TORRENT_FIELDS[location]}" -ef "$INCOMING_TVSHOWS_FOLDER" ]] && FILEBOT_LABEL="ut_label=tv"
        [[ "${TW_TORRENT_FIELDS[location]}" -ef "$INCOMING_OTHER_FOLDER" ]] && FILEBOT_LABEL="ut_label=other"

        state=${TW_TORRENT_FIELDS[state]}
        th=${TW_TORRENT_FIELDS[hash]}

        if [[ ! "${TW_TORRENT_FIELDS[location]}" -ef "$INCOMING_OTHER_FOLDER" ]]; then
            process_torrent
            logger "Processing torrent with ID: $id. $state"
            case $state in
                Stopped|Finished)
                    logger "Archiving torrent with status $state"
                    logger "Removing torrent from list, included data"
                    transmission-remote -t "$id" -rad >>"$LOGFILE" 2>&1
                    [ -d "/tmp/$th" ] && rm -f "/tmp/$th"
                    ;;
                Seeding|Idle)
                    time_spent=${TW_TORRENT_FIELDS[seeding_time]%% seconds)}
                    time_spent=${time_spent##*\(}
                    if ((time_spent >= idleTTL)) || [ "${TW_TORRENT_FIELDS[ratio]%%.*}" -gt "$RATIO" ]; then
                        logger "Archiving torrent with status $state, seeding time ${TW_TORRENT_FIELDS[seeding_time]} and ratio ${TW_TORRENT_FIELDS[ratio]}"
                        logger "Removing seeding/idle torrent from list, included data"
                        transmission-remote -t "$id" -rad >>"$LOGFILE" 2>&1
                        [ -d "/tmp/$th" ] && rm -f "/tmp/$th"
                    else
                        logger "Time spent idling: $time_spent seconds out of $idleTTL: Keep seeding, cabrones!!"
                        logger "Current ratio: ${TW_TORRENT_FIELDS[ratio]} and max. ratio is $RATIO: Keep seeding, cabrones!!"
                    fi
                    ;;
                *) ;;
            esac
        else
            [[ $state =~ Stopped|Finished ]] && transmission-remote -t "$id" -r >>"$LOGFILE" 2>&1
        fi
        FILEBOT_LABEL=""
    done
}
