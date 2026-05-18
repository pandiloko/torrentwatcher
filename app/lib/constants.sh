# Shared constants (no path dependencies on ROOT_FOLDER).

# seconds to delete an idle torrent (259200 seconds = 3 days)
idleTTL=259200
# max ratio after which we can stop seeding and in the case of media torrents delete and trash data
RATIO=2

TORRENT_SERVICE=transmission-daemon
VPN_SERVICE=openvpn

VPN_OK=NL
VPN_EXT=0

FILEBOT_PLEX_TOKEN=""
FILEBOT_LABEL=""

# check cloud for files every 5 minutes (comment in original said 5m; variable is seconds)
CLOUD_DOWNLOAD_INTERVAL=30

VERSION="2.0-coldblooded_Saito"
LICENSE="Copyright (C) $(date '+%Y') Licensed under GPLv3
torrentwatcher comes with ABSOLUTELY NO WARRANTY.  This is free software, and you
are welcome to redistribute it under certain conditions.  See the GNU
General Public License Version 3 for details."

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/root/bin"
