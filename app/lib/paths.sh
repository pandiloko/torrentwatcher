# Path defaults (requires ROOT_FOLDER).

LOGFILE="$ROOT_FOLDER/log/torrentwatcher.log"
LOGFILEBOT="$ROOT_FOLDER/log/filebot.log"
PIDFILE="$ROOT_FOLDER/run/torrentwatcher.pid"

INCOMPLETE_FOLDER="$ROOT_FOLDER/incomplete"
WATCH_MOVIES_FOLDER="$ROOT_FOLDER/watch/movies"
WATCH_TVSHOWS_FOLDER="$ROOT_FOLDER/watch/tvshows"
WATCH_ANIME_FOLDER="$ROOT_FOLDER/watch/anime"
WATCH_OTHER_FOLDER="$ROOT_FOLDER/watch/other"

FILEBOT_CMD=$(type -p filebot) || FILEBOT_CMD="$ROOT_FOLDER/filebot/filebot.sh"

CLOUD_CMD=$(type -p rclone)
RCLONE_CONFIG="$ROOT_FOLDER/rclone.conf"

GEOIP_DB=$ROOT_FOLDER/geoip/GeoLite2-Country.mmdb
GEOIP_CONF=$ROOT_FOLDER/geoip/GeoIP.conf
