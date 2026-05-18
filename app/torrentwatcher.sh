#!/usr/bin/env bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#set -x
#exec > /tmp/tw-debug.log
#exec 2>&1

mypid=$$
CLOUD_MONITOR_PID=""
_tw_finish_done=""

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename "${__file}" .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"

if [ -f /.dockerenv ]; then
    ROOT_FOLDER="/home/watcher"
else
    ROOT_FOLDER="/opt/torrentwatcher"
fi

TW_LIB="${__dir}/lib"
# shellcheck disable=SC1090
for _tw_src in constants paths help config util services cleanup geoip filebot transmission vpn cloud watch environment; do
    # shellcheck source=/dev/null
    source "${TW_LIB}/${_tw_src}.sh"
done
unset _tw_src

OPTS=$(getopt -o v:h:f:d: --long file:,log:,log-filebot:,watch:,watch-other:,incoming:,incoming-other:,output-movies:,output-tvshows:,cloud:,cloud-other:,filebot-cmd:,cloud-cmd:,daemon:,vpn:,no-vpn,verbose,help,version -n 'parse-options' -- "$@")

readopts
check_environment

if [[ -f "$PIDFILE" ]]; then
    oldpid=$(tr -d ' \n' <"$PIDFILE" 2>/dev/null) || oldpid=""
    if [[ -n "$oldpid"  ]] && ps -p "$oldpid" -o pid= >/dev/null 2>&1; then
        logger "TorrentWatcher is already running ($oldpid)"
        exit 0
    fi
    logger "There was a PID file but no corresponding process was running. "
fi

[ -d "$(dirname "$PIDFILE")" ] || mkdir -p "$(dirname "$PIDFILE")"
echo "$mypid" >"$PIDFILE"
trap finish EXIT

logger "Starting TorrentWatcher..."
while ! check_vpn; do
    logger "Waiting for the VPN to start..."
    sleep 10
    continue
done

process_torrent_queue
add_torrents
cloud_monitor &
CLOUD_MONITOR_PID=$!

logger "Entering loop..."
while true; do
    logger "Loop restart"
    update_geoip
    file_monitor
    sleep 10
    logger "Downloading torrent files to watched folder"
    if srv transmission-daemon status; then
        process_torrent_queue
        add_torrents
    fi
    logger "Checking VPN"
    check_vpn
    logger "Loop end"
done
