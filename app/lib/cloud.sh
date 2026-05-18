cloud_list_parsable_torrents() {
    $CLOUD_CMD lsf "cloud:$1" | grep 'torrent$\|magnet.txt$'
}

cloud_delete() {
    $CLOUD_CMD deletefile "cloud:$1"
    return $?
}

cloud_download() {
    $CLOUD_CMD copy "cloud:$1" "$2"
    return $?
}

cloud_monitor() {
    declare -A locations

    locations[$WATCH_MOVIES_FOLDER]="$CLOUD_MOVIES_FOLDER"
    locations[$WATCH_TVSHOWS_FOLDER]="$CLOUD_TVSHOWS_FOLDER"
    locations[$WATCH_ANIME_FOLDER]="$CLOUD_ANIME_FOLDER"
    locations[$WATCH_OTHER_FOLDER]="$CLOUD_OTHER_FOLDER"

    while true; do
        local loc watch_path cloud_path oIFS i
        for loc in "${!locations[@]}"; do
            watch_path="$loc"
            cloud_path="${locations[$loc]}"

            oIFS=$IFS
            IFS=$'\n'
            cd "$loc" || {
                logger "cloud_monitor: cd failed: $loc"
                continue
            }
            for i in $(cloud_list_parsable_torrents "$cloud_path"); do
                logger "Processing file: $i"
                cloud_download "$cloud_path/$i" "$PWD" >>"$LOGFILE" 2>&1 && cloud_delete "$cloud_path/$i" >>"$LOGFILE" 2>&1
            done
            IFS=$oIFS
            sleep 1
        done
        sleep "$CLOUD_DOWNLOAD_INTERVAL"
    done
}
