showconfig() {
    cat <<EOF
System:

idleTTL=$idleTTL
LOGFILE=$LOGFILE
LOGFILEBOT=$LOGFILEBOT
PIDFILE=$PIDFILE
INCOMPLETE_FOLDER=$INCOMPLETE_FOLDER

local watched folders:
WATCH_MOVIES_FOLDER=$WATCH_MOVIES_FOLDER
WATCH_TVSHOWS_FOLDER=$WATCH_TVSHOWS_FOLDER
WATCH_ANIME_FOLDER=$WATCH_ANIME_FOLDER
WATCH_OTHER_FOLDER=$WATCH_OTHER_FOLDER

CLOUD_CMD=$CLOUD_CMD
CLOUD_DOWNLOAD_INTERVAL=$CLOUD_DOWNLOAD_INTERVAL
RCLONE_CONFIG=$RCLONE_CONFIG
TORRENT_SERVICE=$TORRENT_SERVICE
VPN_SERVICE=$VPN_SERVICE
VPN_OK=$VPN_OK
VPN_EXT=$VPN_EXT


Transmission Downloads

INCOMING_MOVIES_FOLDER=$INCOMING_MOVIES_FOLDER
INCOMING_TVSHOWS_FOLDER=$INCOMING_TVSHOWS_FOLDER
INCOMING_ANIME_FOLDER=$INCOMING_ANIME_FOLDER
INCOMING_OTHER_FOLDER=$INCOMING_OTHER_FOLDER
INCOMING_ROOT_FOLDER=$INCOMING_ROOT_FOLDER

Archive:

OUTPUT_MOVIES_FOLDER=$OUTPUT_MOVIES_FOLDER
OUTPUT_TVSHOWS_FOLDER=$OUTPUT_TVSHOWS_FOLDER
OUTPUT_ANIME_FOLDER=$OUTPUT_ANIME_FOLDER

Watched remote folders in cloud provider

CLOUD_MOVIES_FOLDER=$CLOUD_MOVIES_FOLDER
CLOUD_TVSHOWS_FOLDER=$CLOUD_TVSHOWS_FOLDER
CLOUD_ANIME_FOLDER=$CLOUD_ANIME_FOLDER
CLOUD_OTHER_FOLDER=$CLOUD_OTHER_FOLDER


Filebot:

FILEBOT_CMD=$FILEBOT_CMD
FILEBOT_MOVIES_FORMAT=$FILEBOT_MOVIES_FORMAT
FILEBOT_SERIES_FORMAT=$FILEBOT_SERIES_FORMAT
FILEBOT_ANIME_FORMAT=$FILEBOT_ANIME_FORMAT


EOF
}

readconfig() {
    { [ -e "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; } || { echo "Config file $CONFIG_FILE not found"; exit 1; }
    local tmpfile
    tmpfile=$(mktemp /tmp/torrentwatcher.XXXXXX)
    grep -Ei '^[[:space:]]*[a-z_.-]+=[^[;,`()%$!#]+[[:space:]]*$' "$CONFIG_FILE" > "$tmpfile"
    echo "Readed options from file $tmpfile:"
    cat "$tmpfile"
    if [ ! -z "$PS1" ]; then
        while true; do
            read -r -p "Do you want to continue? y / n: " yn
            case $yn in
                [Yy])
                    # shellcheck source=/dev/null
                    source "$tmpfile"
                    break
                    ;;
                [Nn])
                    echo User cancelled
                    exit 1
                    ;;
                *) echo "Please answer with y or n." ;;
            esac
        done
    else
        # shellcheck source=/dev/null
        source "$tmpfile"
    fi
    rm -f "$tmpfile"
}

readopts() {
    echo "$OPTS"
    eval set -- "$OPTS"

    if [ $? != 0 ]; then echo "Failed parsing options." >&2; exit 1; fi
    while true; do
        case "$1" in
            -v | --verbose) VERBOSE=true; shift ;;
            -h | --help) help; exit 0 ;;
            -d | --daemon) DAEMON=true; shift ;;
            -f | --file)
                CONFIG_FILE=$2
                readconfig
                break
                ;;
            --version) version; exit 0 ;;
            --log) LOGFILE="$2"; shift 2 ;;
            --log-filebot) LOGFILEBOT="$2"; shift 2 ;;
            --incomplete) INCOMPLETE_FOLDER="$2"; shift 2 ;;
            --watch) WATCH_MEDIA_FOLDER="$2"; shift 2 ;;
            --watch-other) WATCH_OTHER_FOLDER="$2"; shift 2 ;;
            --incoming-other) INCOMING_OTHER_FOLDER="$2"; shift 2 ;;
            --incoming) INCOMING_MOVIES_FOLDER="$2"; shift 2 ;;
            --output-movies) OUTPUT_MOVIES_FOLDER="$2"; shift 2 ;;
            --output-tvshows) OUTPUT_TVSHOWS_FOLDER="$2"; shift 2 ;;
            --cloud) CLOUD_MEDIA_FOLDER="$2"; shift 2 ;;
            --cloud-other) CLOUD_OTHER_FOLDER="$2"; shift 2 ;;
            --filebot-cmd) FILEBOT_CMD="$2"; shift 2 ;;
            --vpn) VPN_OK="$2"; shift 2 ;;
            --no-vpn) VPN_EXT=1; shift ;;
            --)
                shift
                break
                ;;
            *) break ;;
        esac
    done
}
