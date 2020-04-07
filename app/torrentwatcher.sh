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
OPTS=`getopt -o v:h:f:d: --long file:,log:,log-filebot:,watch:,watch-other:,incoming:,incoming-other:,output-movies:,output-tvshows:,cloud:,cloud-other:,filebot-cmd:,cloud-cmd:,daemon:,vpn:,no-vpn,verbose,help,version -n 'parse-options' -- "$@"`

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"

#seconds to delete an idle torrent (259200 seconds = 3 days)
idleTTL=259200

if [ -f /.dockerenv ]; then
	ROOT_FOLDER="/home/watcher"
else
	ROOT_FOLDER="/opt/torrentwatcher"
fi

LOGFILE="$ROOT_FOLDER/log/torrentwatcher.log"
LOGFILEBOT="$ROOT_FOLDER/log/filebot.log"
PIDFILE="$ROOT_FOLDER/run/torrentwatcher.pid"

INCOMPLETE_FOLDER="$ROOT_FOLDER/incomplete"
WATCH_MEDIA_FOLDER="$ROOT_FOLDER/watch/media"
WATCH_OTHER_FOLDER="$ROOT_FOLDER/watch/other"


FILEBOT_CMD=`type -p filebot` || FILEBOT_CMD="$ROOT_FOLDER/filebot/filebot.sh"

CLOUD_CMD=$(type -p rclone)
#check cloud for files every 5 minutes
CLOUD_DOWNLOAD_INTERVAL=30
RCLONE_CONFIG="$ROOT_FOLDER/rclone.conf"

GEOIP_DB=$ROOT_FOLDER/geoip/GeoLite2-Country.mmdb
GEOIP_CONF=$ROOT_FOLDER/geoip/GeoIP.conf

TORRENT_SERVICE=transmission-daemon
VPN_SERVICE=openvpn

VPN_OK=NL
VPN_EXT=0

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/root/bin"

VERSION="2.0-coldblooded_Saito"
LICENSE="Copyright (C) `date '+%Y'` Licensed under GPLv3
torrentwatcher comes with ABSOLUTELY NO WARRANTY.  This is free software, and you
are welcome to redistribute it under certain conditions.  See the GNU
General Public License Version 3 for details."

help (){
    printf %s "\
torrentwatcher version $VERSION

$LICENSE

torrentwatcher is a simple yet functional script to help with the automation of torrent download and classification

Usage: torrentwatcher [OPTIONS]

Options
     --log FILE              location for the main log file
     --log-filebot FILE      location for the filebot operations log file
     --incomplete PATH       path for all the incomplete downloads
     --incoming PATH         path for the downloaded movies and tv shows
     --incoming-other PATH   path for the other downloaded stuff
     --output-movies PATH    classified movies archive
     --output-tvshows PATH   classified tv shows archive
     --cloud PATH            absolute path for movies and tv shows incoming torrent files in the cloud storage
     --cloud-other PATH      absolute path for other stuff incoming torrent files in the cloud storage
     --filebot-cmd FILE      filebot executable name with path. Default is trying to find with 'which'
     --vpn COUNTRY-ID        Country where VPN IP should be geolocated. Format: ISO 3166-1 alpha-2 (2 characters)
     --no-vpn                VPN is extern

 -f, --file FILE             read configurations from specified file (bash syntax)
 -v, --verbose               increase verbosity
     --version               show version and exit
 -h, --help                  show this help message


"
}

version(){
        printf %s "\
torrentwatcher version $VERSION
"
}

unknow_syntax() {
    version
    printf %s "\
Unknown option or incorrect syntax. Try ussing -h,--help option
"
}

readconfig(){
    # -e file exists
    # -f file is a regular file (not a directory or device file)
    # -s file is not zero size
    { [ -e $CONFIG_FILE ] && [ -f $CONFIG_FILE ] && [ -s $CONFIG_FILE ] ;} || { echo Config file $CONFIG_FILE not found ; exit 1 ;}
    local tmpfile=$(mktemp /tmp/torrentwatcher.XXXXXX)
    grep -Ei '^[[:space:]]*[a-z_.-]+=[^[;,`()%$!#]+[[:space:]]*$' $CONFIG_FILE > $tmpfile
    echo "Readed options from file $tmpfile:"
    cat $tmpfile
    # Ask only if we are interactive
    if [ ! -z "$PS1" ] ; then
        while true; do
            read -p "Do you want to continue? y / n: " yn
            case $yn in
                [Yy] )
                    source $tmpfile
                    break;;
                [Nn] )
                    echo User cancelled
                    exit 1;;
                * ) echo "Please answer with y or n.";;
            esac
        done
    else
        source $tmpfile
    fi
    rm -f $tmpfile
}

showconfig(){
	cat <<EOF
System:

idleTTL=$idleTTL
LOGFILE=$LOGFILE
LOGFILEBOT=$LOGFILEBOT
PIDFILE=$PIDFILE
INCOMPLETE_FOLDER=$INCOMPLETE_FOLDER

local watched folders:
WATCH_MEDIA_FOLDER=$WATCH_MEDIA_FOLDER
WATCH_OTHER_FOLDER=$WATCH_OTHER_FOLDER

CLOUD_CMD=$CLOUD_CMD
CLOUD_DOWNLOAD_INTERVAL=$CLOUD_DOWNLOAD_INTERVAL
RCLONE_CONFIG=$RCLONE_CONFIG
TORRENT_SERVICE=$TORRENT_SERVICE
VPN_SERVICE=$VPN_SERVICE
VPN_OK=$VPN_OK
VPN_EXT=$VPN_EXT


Transmission Downloads

INCOMING_MEDIA_FOLDER=$INCOMING_MEDIA_FOLDER
INCOMING_OTHER_FOLDER=$INCOMING_OTHER_FOLDER

Archive:

OUTPUT_MOVIES_FOLDER=$OUTPUT_MOVIES_FOLDER
OUTPUT_TVSHOWS_FOLDER=$OUTPUT_TVSHOWS_FOLDER
OUTPUT_ANIME_FOLDER=$OUTPUT_ANIME_FOLDER

Watched remote folders in cloud provider

CLOUD_MEDIA_FOLDER=$CLOUD_MEDIA_FOLDER
CLOUD_OTHER_FOLDER=$CLOUD_OTHER_FOLDER


Filebot:

FILEBOT_CMD=$FILEBOT_CMD
FILEBOT_MOVIES_FORMAT=$FILEBOT_MOVIES_FORMAT
FILEBOT_SERIES_FORMAT=$FILEBOT_SERIES_FORMAT
FILEBOT_ANIME_FORMAT=$FILEBOT_ANIME_FORMAT


EOF
}

readopts(){
    echo "$OPTS"
    eval set -- "$OPTS"

    if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
    while true; do
      case "$1" in
        -v | --verbose ) VERBOSE=true; shift ;;
        -h | --help ) help; exit 0 ;;
        -d | --daemon) DAEMON=true; shift ;;
        -f | --file )
            CONFIG_FILE=$2
            readconfig
            break
            ;;
        --version) version; exit 0;;
        --log) LOGFILE="$2"; shift 2 ;;
        --log-filebot) LOGFILEBOT="$2"; shift 2 ;;
        --incomplete) INCOMPLETE_FOLDER="$2"; shift 2 ;;
        --watch) WATCH_MEDIA_FOLDER="$2"; shift 2 ;;
        --watch-other) WATCH_OTHER_FOLDER="$2"; shift 2 ;;
        --incoming-other) INCOMING_OTHER_FOLDER="$2"; shift 2 ;;
        --incoming) INCOMING_MEDIA_FOLDER="$2"; shift 2 ;;
        --output-movies) OUTPUT_MOVIES_FOLDER="$2"; shift 2 ;;
        --output-tvshows) OUTPUT_TVSHOWS_FOLDER="$2"; shift 2 ;;
        --cloud) CLOUD_MEDIA_FOLDER="$2"; shift 2 ;;
        --cloud-other) CLOUD_OTHER_FOLDER="$2"; shift 2 ;;
        --filebot-cmd) FILEBOT_CMD="$2"; shift 2 ;;
        --vpn) VPN_OK="$2"; shift 2 ;;
        --no-vpn) VPN_EXT=1; shift ;;
        -- ) shift; break ;;
        * ) break ;;
      esac
    done
}

check_environment(){
    [ -x "$FILEBOT_CMD" ] || { echo -en "Check the binaries:\n - Filebot: $FILEBOT_CMD \n" && exit 1; }
    [ -x "$CLOUD_CMD" ] || { echo -en "Check the binaries:\n - Cloud: $CLOUD_CMD\n" && exit 1; }

    #try to find a default file
    if [ -z "$CONFIG_FILE" ]; then
        CONFIG_FILE="$ROOT_FOLDER/tw.conf"
        if [ -e $CONFIG_FILE ] && [ -f $CONFIG_FILE ] && [ -s $CONFIG_FILE ] ;then
            echo "Found default config file $CONFIG_FILE"
            readconfig
        fi
    fi
    env

    # Complete missing folders
    [ -z "$INCOMING_MEDIA_FOLDER" ] && INCOMING_MEDIA_FOLDER="$ROOT_FOLDER/media"
    [ -z "$INCOMING_OTHER_FOLDER" ] && INCOMING_OTHER_FOLDER="$ROOT_FOLDER/other"

    #Plex preset creates separate folders
    [ -z "$OUTPUT_MOVIES_FOLDER" ] && OUTPUT_MOVIES_FOLDER="$ROOT_FOLDER/archive"
    [ -z "$OUTPUT_TVSHOWS_FOLDER" ] && OUTPUT_TVSHOWS_FOLDER="$ROOT_FOLDER/archive"
    [ -z "$OUTPUT_ANIME_FOLDER" ] && OUTPUT_ANIME_FOLDER="$ROOT_FOLDER/archive"

    [ -z "$CLOUD_MEDIA_FOLDER" ] && CLOUD_MEDIA_FOLDER="/tw/launching-media"
    [ -z "$CLOUD_OTHER_FOLDER" ] && CLOUD_OTHER_FOLDER="/tw/launching-other"

    #Plex preset creates separate folders
    [ -z "$FILEBOT_MOVIES_FORMAT" ] && FILEBOT_MOVIES_FORMAT="$OUTPUT_MOVIES_FOLDER/{plex}"
    [ -z "$FILEBOT_SERIES_FORMAT" ] && FILEBOT_SERIES_FORMAT="$OUTPUT_TVSHOWS_FOLDER/{plex}"
    [ -z "$FILEBOT_ANIME_FORMAT" ] && FILEBOT_ANIME_FORMAT="$OUTPUT_ANIME_FOLDER/{plex}"

    #rclone config show
    { [ -e $RCLONE_CONFIG ] && export RCLONE_CONFIG=$RCLONE_CONFIG ;} || { echo -en "Check the rclone config:\n - RCLONE_CONFIG: $RCLONE_CONFIG\n" && exit 1; }
    virgin=0
    ls $INCOMPLETE_FOLDER $WATCH_MEDIA_FOLDER $WATCH_OTHER_FOLDER $INCOMING_MEDIA_FOLDER $INCOMING_OTHER_FOLDER $OUTPUT_MOVIES_FOLDER $OUTPUT_TVSHOWS_FOLDER `dirname "$LOGFILE"` `dirname "$LOGFILEBOT"`  &>/dev/null || virgin=1

    if [ $virgin -eq 1 ];then
        echo "It seems to be your first time or some folders are missing. Take a look at my configuration:"
        echo "
Logfiles
 - General log: $LOGFILE
 - Filebot log: $LOGFILEBOT

Folders
 - Incomplete Downloads: $INCOMPLETE_FOLDER
 - Watch media: $WATCH_MEDIA_FOLDER
 - Watch other: $WATCH_OTHER_FOLDER
 - Incoming media: $INCOMING_MEDIA_FOLDER
 - Incoming other $INCOMING_OTHER_FOLDER
 - Archive movies: $OUTPUT_MOVIES_FOLDER
 - Archive TV shows: $OUTPUT_TVSHOWS_FOLDER
 - Cloud remote media: $CLOUD_MEDIA_FOLDER
 - Cloud remote other: $CLOUD_OTHER_FOLDER
"
        # Ask only if we are interactive, else just try to create
        if [ ! -z "$PS1" ] ; then
            while true; do
                read -p "Should I try to create the missing folders? y / n: " yn
                case $yn in
                    [Yy] )
                        mkdir -p `dirname "$LOGFILE"` `dirname "$LOGFILEBOT"` $INCOMING_MEDIA_FOLDER  $INCOMING_OTHER_FOLDER $OUTPUT_MOVIES_FOLDER $OUTPUT_TVSHOWS_FOLDER $WATCH_MEDIA_FOLDER  $WATCH_OTHER_FOLDER $INCOMPLETE_FOLDER||  exit 1
                        break
                        ;;
                    [Nn] )
                        echo "Exiting..."
                        exit 1
                        ;;
                    * ) echo "Please answer with y or n.";;
                esac
            done
        else
            mkdir -p `dirname "$LOGFILE"` `dirname "$LOGFILEBOT"` $INCOMING_MEDIA_FOLDER  $INCOMING_OTHER_FOLDER $OUTPUT_MOVIES_FOLDER $OUTPUT_TVSHOWS_FOLDER $WATCH_MEDIA_FOLDER  $WATCH_OTHER_FOLDER $INCOMPLETE_FOLDER||  exit 1
        fi
    fi
    # FILEBOT_MOVIES_FORMAT="$OUTPUT_MOVIES_FOLDER{y} {n} [{rating}]/{n} - {y} - {genres} {group}"
    # FILEBOT_SERIES_FORMAT="$OUTPUT_TVSHOWS_FOLDER{n}/Season {s}/{s+'x'}{e.pad(2)} - {t} {group}"
    # FILEBOT_ANIME_FORMAT="$OUTPUT_TVSHOWS_FOLDER{n}/Season {s}/{s+'x'}{e.pad(2)} - {t}"
    echo "Final Configuration Complete:"
    showconfig
}

#setsid myscript.sh >/dev/null 2>&1 < /dev/null &
#exec > "$logfile" 2>&1 </dev/null
# tail -fn0 logfile | awk '/pattern/ { print | "command" }'

# killtree - not used. Testing only
killtree() {
    local _pid=$1
    local _sig=${2:--TERM}
    kill -stop ${_pid} # needed to stop quickly forking parent from producing children between child killing and parent killing
    for _child in $(ps -o pid --no-headers --ppid ${_pid}); do
        killtree ${_child} ${_sig}
    done
    kill -${_sig} ${_pid}
}

finish (){
    logger "Finishing TorrentWatcher. Cleaning up tasks..."
    srv transmission-daemon stop >> $LOGFILE 2>&1
    srv $VPN_SERVICE stop >> $LOGFILE 2>&1
    rm -rf $PIDFILE
    # TODO: PROCESS KILLING NEEDS TESTING
    ############
    /bin/kill -- -$mypid #kill all child processes
    ############
    # PGID=$(ps -o pgid= $PID | grep -o [0-9]*)
    # kill -TERM -"$PGID"  # kill -15
    ############
    # killtree $@
    ############

    wait
}

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}

logger (){
    echo "[torrentwatcher] `date +'%Y.%m.%d-%H:%M:%S'` [$mypid] - $1" >> $LOGFILE
}
update_geoip (){
    if [ $(find "$GEOIP_DB" -mmin +300 | wc -l) -gt 0 ]; then
        geoipupdate -f $GEOIP_CONF
	touch $GEOIP_DB
    fi
}

filebot_license (){
    #just check if license is written in the usual place, otherwise try to import it
    [ -f ~/.filebot/license.txt ] || filebot --license $ROOT_FOLDER/FileBot_License_*.psm
}

###########################################
####### Here begins the real meat##########
###########################################

extract_info () {
# Parameters:
#     $1 -> torrent id
# extract info from torrent and create GLOBAL variables accordingly
# variable names are lowercased and spaces replaced with underscores
###############################################################################
    [[ `echo $-` =~ .*x.* ]] && set +x && local restore=yes #comment/uncomment for a cleaner output when using xtrace option
    oIFS=$IFS
    IFS=$'\n'
    for i in `transmission-remote -t $1 -i| grep ":"` ;do
        # "  Date finished :    Thu Feb 16 10:52:21 2017"
        key="${i%%:*}"
        # "  Date finished "
        key="`trim \"$key\"`"
        # "Date finished"
        key=${key// /_}
        # "Date_finished"
        key=${key,,}
        # "date_finished"

        value="${i#*:}"
        # "    Thu Feb 16 10:52:21 2017"
        value="`trim \"$value\"`"
        # "Thu Feb 16 10:52:21 2017"

        declare -g $key=$value
    done
    IFS=$oIFS
    [[ $restore == "yes" ]] && set -x #comment/uncomment for a cleaner output when using xtrace option
}

add_torrents (){
        shopt -u | grep -q nocasematch && local ch_nocasematch=true && shopt -s nocasematch
        transmission-remote -w "$INCOMING_MEDIA_FOLDER" >> $LOGFILE 2>&1
        for i in ${WATCH_MEDIA_FOLDER}/*.torrent ; do
            [ -e "$i" ] || continue
            logger "Adding media torrents: $i"
            transmission-remote -a "$i" -w "$INCOMING_MEDIA_FOLDER" >> $LOGFILE 2>&1 && mv "$i" "$i.added"
        done
        for i in ${WATCH_OTHER_FOLDER}/*.torrent ; do
            [ -e "$i" ] || continue
            logger "Adding other torrents: $i"
            transmission-remote -a "$i" -w "$INCOMING_OTHER_FOLDER" >> $LOGFILE 2>&1 && mv "$i" "$i.added"
        done

        if [ -e ${WATCH_OTHER_FOLDER}/magnet.txt ]; then
        logger "Processing magnet file"
            (
            while IFS='' read -r i || [[ -n "$line" ]]; do
                        transmission-remote -a "$i" -w "$INCOMING_OTHER_FOLDER" >> $LOGFILE 2>&1 && echo  "$i" >> "${WATCH_OTHER_FOLDER}/magnet.txt.added"
            echo "Text read from file: $line"
            done < "${WATCH_OTHER_FOLDER}/magnet.txt"
            )
            rm -f "${WATCH_OTHER_FOLDERa}/magnet.txt"
        fi

        [ $ch_nocasematch ] && shopt -u nocasematch; unset ch_nocasematch
}
filebot_command(){
# parameters:
#     $1-> action [copy|move|link]
#     $2-> src folder
# Determines if file is alone or in a folder because we don't want to process the whole folder
###############################################################################
    $FILEBOT_CMD -script fn:amc -non-strict --def movieFormat="$FILEBOT_MOVIES_FORMAT" seriesFormat="$FILEBOT_SERIES_FORMAT" animeFormat="$FILEBOT_ANIME_FORMAT" music=n excludeList=$ROOT_FOLDER/log/amc-exclude.txt subtitles=en --log-file $ROOT_FOLDER/log/amc.log --conflict auto --lang en --log all --action $1 "$2" >> $LOGFILE 2>&1
    return $?
}

process_torrent(){
    local ret=1337
    if [ -d "${INCOMING_MEDIA_FOLDER}/$name" ]; then
        if [ ! -f /tmp/filebot-$hash.log ]  ;then
            filebot_command copy "${INCOMING_MEDIA_FOLDER}/$name" &> /tmp/filebot-$hash.log
            ret=$?
            #if grep  -E 'Failure\|java\.io\.IOException' /tmp/filebot-$hash.log &>/dev/null; then
            #   echo rsync -rvhP --size-only "${INCOMING_MEDIA_FOLDER}/$name" "$INCOMING_OTHER_FOLDER/misc" >> $LOGFILE
            #fi
        fi
    else
        filebot_command copy "${INCOMING_MEDIA_FOLDER}" &> /tmp/filebot-$hash.log
        ret=$?
    fi
    #0 ... SUCCESS
    #1 ... COMMAND-LINE ERROR (bad command-line syntax, your bad, couldn't possibly work)
    #2 ... BAD LICENSE (no license or expired license, causing a failure)
    #3 ... FAILURE (script crashes due to error, something that could work, but doesn't, maybe due to network issues)
    #4 ... DIE (script aborts on purpose)
    #100 ... NOOP (script successfully did nothing)
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
        *)
            rm /tmp/filebot-$hash.log
            ret=1
            ;;
    esac
#    [ $ret -ne 0 ] && rm /tmp/filebot-$hash.log
    return $ret
}
process_torrent_queue (){
# Collects torrents with 100% Download and process them depending on State.
# Stopped | Finished | Idle -> ensure files are copied and REMOVE FROM TRANSMISSION INCLUDING DATA
# Seeding -> copy file and let it be until ratio is reached
###############################################################################
# TODO:
#   - implement Idle timeout.
#   - check permissions
#   - move to temporary folder when "rad". Delete timebased
###############################################################################

    for id in `transmission-remote -l|sed -e '1d;$d;'|grep "100%"| tr -s ' '| cut -f2 -d ' ' | grep -Eo '[0-9]+'`
    do
        # Copy infos into properly named lowercased variables
        extract_info $id
        if [[ "$location" -ef "$INCOMING_MEDIA_FOLDER" ]] ; then
            process_torrent
            logger "Processing torrent with ID: $id. $state"
            case $state in
                Stopped|Finished)
                    logger "Archiving torrent with status $state"
                    # ensure the files are already copied and remove the torrent+data from Transmission
                    logger "Removing torrent from list, included data"
                    transmission-remote -t $id -rad >> $LOGFILE 2>&1
                    [ -d /tmp/$hash ] && rm -f /tmp/$hash
                ;;
                Seeding|Idle)
                    local time_spent=${seeding_time%% seconds)}
                    time_spent=${time_spent##*\(}
                    if (( $time_spent >= $idleTTL ));then
                        logger "Archiving torrent with status $state and seeding time $seeding_time"
                        # ensure the files are already copied and remove the torrent+data from Transmission
                        logger "Removing seeding/idle torrent from list, included data"
                        transmission-remote -t $id -rad >> $LOGFILE 2>&1
                        [ -d /tmp/$hash ] && rm -f /tmp/$hash
                    else
                        logger "$time_spent seconds out of $idleTTL: Keep seeding, cabrones!!"
                    fi
                ;;
                *)
                ;;
            esac
        fi
        # OTHER folder - remove torrent if finished, preserve disk data
        [[ "$location" -ef "$INCOMING_OTHER_FOLDER" ]] && [[ $state =~ Stopped|Finished ]] && transmission-remote -t $id -r >> $LOGFILE 2>&1
    done
}

srv(){
# parameters:
#     $1-> service
#     $2-> action [start,stop,status,restart]
# Performs the desired action with the requested service using the appropiate call
# Some light OS detection decides if we are in docker container or FreeBSD and
# then falls back to systemd
###############################################################################

    local ret=""
    if [ -f /.dockerenv ]; then
        #We are in container
        case $2 in
            start|stop|restart|status)
                sudo supervisorctl $2 $1
                return $?
                ;;
            status)
                ret=$(sudo supervisoctl $2 $1 | grep -w STOPPED)
                { [[ $ret == "STOPPED" ]] && return 1 ;}|| return 0
                ;;
            *)
                return 1
                ;;
        esac
    elif uname -a | grep -i freebsd ; then
        #We are in freebsd
        case $2 in
            start|stop|restart|status)
                sudo service $1 $2
                return
                ;;
            *)
                return 1
                ;;
        esac
    else
        #We are in some major distro with systemd
        case $2 in
            start|stop|restart)
                sudo systemctl $2 $1
                return $?
                ;;
            status)
                ret=$(sudo systemctl is-active $1)
                return $?
                ;;
            *)
                return 1
                ;;
        esac
    fi

    logger "We should never reach this point"
    return 1
}
check_vpn(){
# Checks if we are going out through VPN and start/stop transmission accordingly
#
# this is not reliable, we get null from time to time
# vpn=$(wget -qO -  ipinfo.io/country)
#
# Alternative and arguably better method with dig is now used
###############################################################################
    myip=$(
        dig +short -4 -t a @resolver1.opendns.com   myip.opendns.com        2>/dev/null ||\
        dig +short -4 -t a @ns1-1.akamaitech.net    whoami.akamai.net       2>/dev/null ||\
        dig +short -4 -t a @resolver1.opendns.com   myip.opendns.com        2>/dev/null ||\
        dig +short -t txt  @ns1.google.com          o-o.myaddr.l.google.com 2>/dev/null | tr -d '"'
    )
    # vpn=`mmdblookup --file /opt/GeoIP/GeoLite2-Country.mmdb --ip 80.60.233.195 country iso_code| grep '"'| grep -oP '\s+"\K\w+'`
    vpn=`mmdblookup -f $GEOIP_CONF --file $GEOIP_DB --ip $myip country iso_code| grep '"'| grep -oP '\s+"\K\w+'`
    if [[ "$vpn" == "$VPN_OK" ]]
        then
        logger "Geolocated in Country: $vpn"
        srv transmission-daemon status | grep RUNNING || { srv transmission-daemon start && sleep 5 ;}
        if [ $VPN_EXT -eq 0 ]; then
		srv $VPN_SERVICE status ;
	fi
	return 
    else
        logger "We are not in VPN!! Country: $vpn"
        logger "Trying to stop transmission..."
        srv transmission-daemon stop >> $LOGFILE 2>&1
        if [ $VPN_EXT -eq 0 ]; then
            logger "Restarting VPN..."
            srv $VPN_SERVICE restart
        fi
    fi
}

cloud_list_parsable_torrents(){
    #dropbox_downloader
    #$CLOUD_CMD list "$1" | tr -s " " | cut -d " " -f4-|grep -E "\.torrent$"
    #rclone
    $CLOUD_CMD lsf "cloud:$1" | grep torrent$
}
cloud_delete(){
    $CLOUD_CMD deletefile "cloud:$1"
    return $?
}
cloud_download(){
    $CLOUD_CMD copy "cloud:$1" "$2"
    return $?
}

cloud_monitor () {
# Waits for changes in cloud folders
# Downloads ONLY .torrent files to watch folders, deleting from cloud if download is successful
# Use this one for dropbox_uploader or implement your own function for other clouds
###############################################################################
    while true
    do
        # Monitor folders for changes
        #pids=""
        #$CLOUD_CMD monitor $CLOUD_MEDIA_FOLDER 60 >> $LOGFILE 2>&1 &
        #pids="$pids $!"
        #$CLOUD_CMD monitor $CLOUD_OTHER_FOLDER 60 >> $LOGFILE 2>&1 &
        #pids="$pids $!"
        #for pid in $pids; do
        #    wait $pid
        #done

    # Monitor mode was cool but rclone does not support it
    # TODO: test if mount is reliable enough
        #Download files
        oIFS=$IFS
        IFS=$'\n'
        cd $WATCH_MEDIA_FOLDER
    for i in $(cloud_list_parsable_torrents $CLOUD_MEDIA_FOLDER); do
        logger "Processing file: $i"
        # Download but do not delete if download fails
        cloud_download "$CLOUD_MEDIA_FOLDER/$i" $PWD >> $LOGFILE 2>&1 && cloud_delete "$CLOUD_MEDIA_FOLDER/$i" >> $LOGFILE 2>&1

    done
    cd $WATCH_OTHER_FOLDER
    for i in $(cloud_list_parsable_torrents $CLOUD_OTHER_FOLDER); do
        logger "Processing file: $i"
        # Download but do not delete if download fails
        cloud_download "$CLOUD_OTHER_FOLDER/$i" $PWD >> $LOGFILE 2>&1 && cloud_delete "$CLOUD_OTHER_FOLDER/$i" >> $LOGFILE 2>&1
    done
    IFS=$oIFS
    sleep $CLOUD_DOWNLOAD_INTERVAL
    done
}

file_monitor(){
# Waits for changes in watch folders
###############################################################################
    inotifywait -q -t 120 -e close_write,moved_to,modify $WATCH_MEDIA_FOLDER $WATCH_OTHER_FOLDER
}

################################
# EXECUTION STARTS HERE
###############################

readopts
check_environment

if ls $PIDFILE &>/dev/null; then
    if ps aux | grep `cat $PIDFILE` &>/dev/null ;then
        logger "TorrenWatcher is already running (`cat $PIDFILE`)"
        exit 0
    fi
    logger "There was a PID file but no corresponding process was running. "
fi


[ -d "`dirname $PIDFILE`" ] || mkdir -p "`dirname $PIDFILE`"
echo $mypid > $PIDFILE
trap finish EXIT

logger "Starting TorrentWatcher..."
check_vpn

process_torrent_queue
add_torrents

#cloud_monitor only needed if there isn't any other cloud monitor service installed and running
cloud_monitor &

logger "Entering loop..."
while true
do
    update_geoip
    file_monitor
    sleep 10 # Let some time to finish eventual subsequent uploads
    logger "Downloading torrent files to watched folder"
    if srv transmission-daemon status ; then
        process_torrent_queue
        add_torrents
    fi
    logger "Checking VPN"
    check_vpn
done

