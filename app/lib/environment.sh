check_environment() {
    [ -x "$FILEBOT_CMD" ] || { echo -en "Check the binaries:\n - Filebot: $FILEBOT_CMD \n" && exit 1; }
    [ -x "$CLOUD_CMD" ] || { echo -en "Check the binaries:\n - Cloud: $CLOUD_CMD\n" && exit 1; }

    if [ -z "${CONFIG_FILE:-}" ]; then
        CONFIG_FILE="$ROOT_FOLDER/tw.conf"
        if [ -e "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
            echo "Found default config file $CONFIG_FILE"
            readconfig
        fi
    fi

    [ -z "${INCOMING_MOVIES_FOLDER:-}" ] && INCOMING_MOVIES_FOLDER="$ROOT_FOLDER/movies"
    [ -z "${INCOMING_TVSHOWS_FOLDER:-}" ] && INCOMING_TVSHOWS_FOLDER="$ROOT_FOLDER/tvshows"
    [ -z "${INCOMING_ANIME_FOLDER:-}" ] && INCOMING_ANIME_FOLDER="$ROOT_FOLDER/anime"
    [ -z "${INCOMING_OTHER_FOLDER:-}" ] && INCOMING_OTHER_FOLDER="$ROOT_FOLDER/other"
    [ -z "${INCOMING_ROOT_FOLDER:-}" ] && INCOMING_ROOT_FOLDER="$ROOT_FOLDER"

    [ -z "${OUTPUT_MOVIES_FOLDER:-}" ] && OUTPUT_MOVIES_FOLDER="$ROOT_FOLDER/archive"
    [ -z "${OUTPUT_TVSHOWS_FOLDER:-}" ] && OUTPUT_TVSHOWS_FOLDER="$ROOT_FOLDER/archive"
    [ -z "${OUTPUT_ANIME_FOLDER:-}" ] && OUTPUT_ANIME_FOLDER="$ROOT_FOLDER/archive"

    [ -z "${CLOUD_MOVIES_FOLDER:-}" ] && CLOUD_MOVIES_FOLDER="/tw/launching-movies"
    [ -z "${CLOUD_TVSHOWS_FOLDER:-}" ] && CLOUD_TVSHOWS_FOLDER="/tw/launching-tvshows"
    [ -z "${CLOUD_ANIME_FOLDER:-}" ] && CLOUD_ANIME_FOLDER="/tw/launching-anime"
    [ -z "${CLOUD_OTHER_FOLDER:-}" ] && CLOUD_OTHER_FOLDER="/tw/launching-other"

    [ -z "${FILEBOT_MOVIES_FORMAT:-}" ] && FILEBOT_MOVIES_FORMAT="$OUTPUT_MOVIES_FOLDER/{plex}"
    [ -z "${FILEBOT_SERIES_FORMAT:-}" ] && FILEBOT_SERIES_FORMAT="$OUTPUT_TVSHOWS_FOLDER/{plex}"
    [ -z "${FILEBOT_ANIME_FORMAT:-}" ] && FILEBOT_ANIME_FORMAT="$OUTPUT_ANIME_FOLDER/{plex}"

    { [ -e "$RCLONE_CONFIG" ] && export RCLONE_CONFIG=$RCLONE_CONFIG; } || {
        echo -en "Check the rclone config:\n - RCLONE_CONFIG: $RCLONE_CONFIG\n" && exit 1
    }
    virgin=0
    ls "$INCOMPLETE_FOLDER" "$WATCH_ANIME_FOLDER" "$WATCH_MOVIES_FOLDER" "$WATCH_TVSHOWS_FOLDER" "$WATCH_OTHER_FOLDER" \
        "$INCOMING_ANIME_FOLDER" "$INCOMING_TVSHOWS_FOLDER" "$INCOMING_MOVIES_FOLDER" "$INCOMING_OTHER_FOLDER" \
        "$OUTPUT_ANIME_FOLDER" "$OUTPUT_MOVIES_FOLDER" "$OUTPUT_TVSHOWS_FOLDER" "$(dirname "$LOGFILE")" "$(dirname "$LOGFILEBOT")" &>/dev/null || virgin=1

    if [ "$virgin" -eq 1 ]; then
        echo "It seems to be your first time or some folders are missing. Take a look at my configuration:"
        echo "
Logfiles
 - General log: $LOGFILE
 - Filebot log: $LOGFILEBOT

Folders
 - Incomplete Downloads: $INCOMPLETE_FOLDER
 - Watch Movies: $WATCH_MOVIES_FOLDER
 - Watch TV Shows: $WATCH_TVSHOWS_FOLDER
 - Watch anime: $WATCH_ANIME_FOLDER
 - Watch other: $WATCH_OTHER_FOLDER
 - Incoming movies: $INCOMING_MOVIES_FOLDER
 - Incoming tvshow: $INCOMING_TVSHOWS_FOLDER
 - Incoming anime: $INCOMING_ANIME_FOLDER
 - Incoming other: $INCOMING_OTHER_FOLDER
 - Archive Movies: $OUTPUT_MOVIES_FOLDER
 - Archive TV shows: $OUTPUT_TVSHOWS_FOLDER
 - Archive Anime: $OUTPUT_ANIME_FOLDER
 - Cloud movies: $CLOUD_MOVIES_FOLDER
 - Cloud tvshows: $CLOUD_TVSHOWS_FOLDER
 - Cloud anime: $CLOUD_ANIME_FOLDER
 - Cloud other: $CLOUD_OTHER_FOLDER
"
        if [ ! -z "$PS1" ]; then
            while true; do
                read -r -p "Should I try to create the missing folders? y / n: " yn
                case $yn in
                    [Yy])
                        mkdir -p "$(dirname "$LOGFILE")" "$(dirname "$LOGFILEBOT")" "$INCOMING_ANIME_FOLDER" "$INCOMING_TVSHOWS_FOLDER" "$INCOMING_MOVIES_FOLDER" \
                            "$INCOMING_OTHER_FOLDER" "$OUTPUT_MOVIES_FOLDER" "$OUTPUT_TVSHOWS_FOLDER" "$WATCH_ANIME_FOLDER" "$WATCH_MOVIES_FOLDER" "$WATCH_TVSHOWS_FOLDER" \
                            "$WATCH_OTHER_FOLDER" "$INCOMPLETE_FOLDER" || exit 1
                        break
                        ;;
                    [Nn])
                        echo "Exiting..."
                        exit 1
                        ;;
                    *) echo "Please answer with y or n." ;;
                esac
            done
        else
            mkdir -p "$(dirname "$LOGFILE")" "$(dirname "$LOGFILEBOT")" "$INCOMING_ANIME_FOLDER" "$INCOMING_TVSHOWS_FOLDER" "$INCOMING_MOVIES_FOLDER" \
                "$INCOMING_OTHER_FOLDER" "$OUTPUT_MOVIES_FOLDER" "$OUTPUT_TVSHOWS_FOLDER" "$WATCH_ANIME_FOLDER" "$WATCH_MOVIES_FOLDER" "$WATCH_TVSHOWS_FOLDER" \
                "$WATCH_OTHER_FOLDER" "$INCOMPLETE_FOLDER" || exit 1
        fi
    fi
    echo "Final Configuration Complete:"
    showconfig
}
