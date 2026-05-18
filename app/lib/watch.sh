file_monitor() {
    inotifywait -q -t 120 -e close_write,moved_to,modify "$WATCH_MOVIES_FOLDER" "$WATCH_TVSHOWS_FOLDER" "$WATCH_ANIME_FOLDER" "$WATCH_OTHER_FOLDER"
}
