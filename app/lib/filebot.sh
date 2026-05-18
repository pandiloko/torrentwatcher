filebot_license() {
    [ -f ~/.filebot/license.txt ] || filebot --license "$ROOT_FOLDER"/FileBot_License_*.psm
}

filebot_command() {
    set -x
    $FILEBOT_CMD -script fn:amc -non-strict --def movieDB=TheMovieDB seriesDB=TheTVDB animeDB=TheTVDB movieFormat="$FILEBOT_MOVIES_FORMAT" seriesFormat="$FILEBOT_SERIES_FORMAT" animeFormat="$FILEBOT_ANIME_FORMAT" music=n excludeList="$ROOT_FOLDER/log/amc-exclude.txt" subtitles=en $FILEBOT_PLEX_TOKEN $FILEBOT_LABEL --log-file "$ROOT_FOLDER/log/amc.log" --conflict auto --lang en --log all --output "$ROOT_FOLDER" --action "$1" "$2" >>"$LOGFILE" 2>&1
    local ret=$?
    set +x
    return $ret
}
