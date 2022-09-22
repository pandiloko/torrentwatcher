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

# seconds to delete an idle torrent (259200 seconds = 3 days)
idleTTL=259200
# max ratio after which we can stop seeding and in the case of media torrents delete and trash data
RATIO=2

if [ -f /.dockerenv ]; then
    ROOT_FOLDER="/home/watcher"
else
    ROOT_FOLDER="/opt/torrentwatcher"
fi

LOGFILE="$ROOT_FOLDER/log/torrentwatcher.log"
LOGFILEBOT="$ROOT_FOLDER/log/filebot.log"
PIDFILE="$ROOT_FOLDER/run/torrentwatcher.pid"

INCOMPLETE_FOLDER="$ROOT_FOLDER/incomplete"
WATCH_MOVIES_FOLDER="$ROOT_FOLDER/watch/movies"
WATCH_TVSHOWS_FOLDER="$ROOT_FOLDER/watch/tvshows"
WATCH_ANIME_FOLDER="$ROOT_FOLDER/watch/anime"
WATCH_OTHER_FOLDER="$ROOT_FOLDER/watch/other"


FILEBOT_PLEX_TOKEN=""
FILEBOT_LABEL=""
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
        --incoming) INCOMING_MOVIES_FOLDER="$2"; shift 2 ;;
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
    #( set -o posix ; set )

    # Complete missing folders
    [ -z "$INCOMING_MOVIES_FOLDER" ] && INCOMING_MOVIES_FOLDER="$ROOT_FOLDER/movies"
    [ -z "$INCOMING_TVSHOWS_FOLDER" ] && INCOMING_TVSHOWS_FOLDER="$ROOT_FOLDER/tvshows"
    [ -z "$INCOMING_ANIME_FOLDER" ] && INCOMING_ANIME_FOLDER="$ROOT_FOLDER/anime"
    [ -z "$INCOMING_OTHER_FOLDER" ] && INCOMING_OTHER_FOLDER="$ROOT_FOLDER/other"

    #Plex preset creates separate folders
    [ -z "$OUTPUT_MOVIES_FOLDER" ] && OUTPUT_MOVIES_FOLDER="$ROOT_FOLDER/archive"
    [ -z "$OUTPUT_TVSHOWS_FOLDER" ] && OUTPUT_TVSHOWS_FOLDER="$ROOT_FOLDER/archive"
    [ -z "$OUTPUT_ANIME_FOLDER" ] && OUTPUT_ANIME_FOLDER="$ROOT_FOLDER/archive"

    [ -z "$CLOUD_MOVIES_FOLDER" ] && CLOUD_MOVIES_FOLDER="/tw/launching-movies"
    [ -z "$CLOUD_TVSHOWS_FOLDER" ] && CLOUD_TVSHOWS_FOLDER="/tw/launching-tvshows"
    [ -z "$CLOUD_ANIME_FOLDER" ] && CLOUD_ANIME_FOLDER="/tw/launching-anime"
    [ -z "$CLOUD_OTHER_FOLDER" ] && CLOUD_OTHER_FOLDER="/tw/launching-other"

    #Plex preset creates separate folders
    [ -z "$FILEBOT_MOVIES_FORMAT" ] && FILEBOT_MOVIES_FORMAT="$OUTPUT_MOVIES_FOLDER/{plex}"
    [ -z "$FILEBOT_SERIES_FORMAT" ] && FILEBOT_SERIES_FORMAT="$OUTPUT_TVSHOWS_FOLDER/{plex}"
    [ -z "$FILEBOT_ANIME_FORMAT" ] && FILEBOT_ANIME_FORMAT="$OUTPUT_ANIME_FOLDER/{plex}"

    #rclone config show
    { [ -e $RCLONE_CONFIG ] && export RCLONE_CONFIG=$RCLONE_CONFIG ;} || { echo -en "Check the rclone config:\n - RCLONE_CONFIG: $RCLONE_CONFIG\n" && exit 1; }
    virgin=0
    ls $INCOMPLETE_FOLDER $WATCH_ANIME_FOLDER $WATCH_MOVIES_FOLDER $WATCH_TVSHOWS_FOLDER $WATCH_OTHER_FOLDER $INCOMING_ANIME_FOLDER $INCOMING_TVSHOWS_FOLDER $INCOMING_MOVIES_FOLDER $INCOMING_OTHER_FOLDER $OUTPUT_TVHOWS_FOLDER $OUTPUT_MOVIES_FOLDER $OUTPUT_TVSHOWS_FOLDER `dirname "$LOGFILE"` `dirname "$LOGFILEBOT"`  &>/dev/null || virgin=1

    if [ $virgin -eq 1 ];then
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
 - Incoming other $INCOMING_OTHER_FOLDER
 - Archive Movies: $OUTPUT_MOVIES_FOLDER
 - Archive TV shows: $OUTPUT_TVSHOWS_FOLDER
 - Archive Anime: $OUTPUT_ANIME_FOLDER
 - Cloud remote media: $CLOUD_MEDIA_FOLDER
 - Cloud remote other: $CLOUD_OTHER_FOLDER
"
        # Ask only if we are interactive, else just try to create
        if [ ! -z "$PS1" ] ; then
            while true; do
                read -p "Should I try to create the missing folders? y / n: " yn
                case $yn in
                    [Yy] )
                        mkdir -p `dirname "$LOGFILE"` `dirname "$LOGFILEBOT"` $INCOMING_ANIME_FOLDER $INCOMING_TVSHOWS_FOLDER $INCOMING_MOVIES_FOLDER  $INCOMING_OTHER_FOLDER $OUTPUT_MOVIES_FOLDER $OUTPUT_TVSHOWS_FOLDER $WATCH_ANIME_FOLDER $WATCH_MOVIES_FOLDER $WATCH_TVSHOWS_FOLDER $WATCH_OTHER_FOLDER $INCOMPLETE_FOLDER||  exit 1
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
            mkdir -p `dirname "$LOGFILE"` `dirname "$LOGFILEBOT"` $INCOMING_ANIME_FOLDER $INCOMING_TVSHOWS_FOLDER $INCOMING_MOVIES_FOLDER  $INCOMING_OTHER_FOLDER $OUTPUT_MOVIES_FOLDER $OUTPUT_TVSHOWS_FOLDER $WATCH_ANIME_FOLDER $WATCH_MOVIES_FOLDER $WATCH_TVSHOWS_FOLDER $WATCH_OTHER_FOLDER $INCOMPLETE_FOLDER||  exit 1
        fi
    fi
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
    srv transmission-daemon stop |& tee -a $LOGFILE
    srv $VPN_SERVICE stop |& tee -a $LOGFILE
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
    echo "[torrentwatcher] `date +'%Y.%m.%d-%H:%M:%S'` [$mypid] - $1" | tee -a $LOGFILE
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
        transmission-remote -w "$INCOMING_MOVIES_FOLDER" >> $LOGFILE 2>&1
        for i in ${WATCH_MOVIES_FOLDER}/*.torrent ; do
            [ -e "$i" ] || continue
            logger "Adding media torrents: $i"
            transmission-remote -a "$i" -w "$INCOMING_MOVIES_FOLDER" >> $LOGFILE 2>&1 && mv "$i" "$i.added"
        done
        for i in ${WATCH_TVSHOWS_FOLDER}/*.torrent ; do
            [ -e "$i" ] || continue
            logger "Adding tvshows torrents: $i"
            transmission-remote -a "$i" -w "$INCOMING_TVSHOWS_FOLDER" >> $LOGFILE 2>&1 && mv "$i" "$i.added"
        done
        for i in ${WATCH_ANIME_FOLDER}/*.torrent ; do
            [ -e "$i" ] || continue
            logger "Adding media torrents: $i"
            transmission-remote -a "$i" -w "$INCOMING_ANIME_FOLDER" >> $LOGFILE 2>&1 && mv "$i" "$i.added"
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
    #filebot requires a common output directory now. As long as an absolute path is defined with movieFormat, etc. it won't be used
    # argument is '--output PATH' and PATH must exist and be a directory. We default to $ROOT_FOLDER
    Activating '-x' option to record command in hash log
    set -x
    $FILEBOT_CMD -script fn:amc -non-strict --def movieDB=TheMovieDB seriesDB=TheMovieDB::TV animeDB=TheMovieDB::TV movieFormat="$FILEBOT_MOVIES_FORMAT" seriesFormat="$FILEBOT_SERIES_FORMAT" animeFormat="$FILEBOT_ANIME_FORMAT" music=n excludeList=$ROOT_FOLDER/log/amc-exclude.txt subtitles=en $FILEBOT_PLEX_TOKEN $FILEBOT_LABEL --log-file $ROOT_FOLDER/log/amc.log --conflict auto --lang en --log all --output "$ROOT_FOLDER" --action $1 "$2" >> $LOGFILE 2>&1
    local ret=$?
    set +x
    return $ret
}

process_torrent(){
    local ret=1337
    #Why do we make a copy of exclude list?
    # If fail bot fails with e.g. server not found (no internet) this function will 
    # delete the hash file and the next time the torrent will be processed. 
    # The problem is that filebot writes the files to the exclude list also on error exit codes. 
    # This is to avoid endless loops. 
    # to go around this we save the previous exclude file and if the exit code is error
    # we delete both the hash file and the exclude file
    # TODO: differentiate between unrecoverable error (file not found, search failed, no permissions)
    # recoverable errors (internet down)
    cp $ROOT_FOLDER/log/amc-exclude.txt $ROOT_FOLDER/log/amc-exclude.txt.previous

    if [ -d "$location/$name" ];then
        if [ ! -f /tmp/filebot-$hash.log ]  ;then
            filebot_command copy "$location/$name" &> /tmp/filebot-$hash.log
            ret=$?
        fi
    elif [ -f "$location/$name" ];then
        filebot_command copy "$location" &> /tmp/filebot-$hash.log
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
	3)
	    logger "recoverable error??"
	    # TODO parse for "Networ Error"
            rm /tmp/filebot-$hash.log
            # as explained before we restore the exclude file we saved before the filebot call
            # because filebot registers the files even when the operation has failed
            mv $ROOT_FOLDER/log/amc-exclude.txt.previous $ROOT_FOLDER/log/amc-exclude.txt
            ret=1
	    ;;

        *)
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
    #( set -o posix ; set )
    [[ "$location" -ef "$INCOMING_ANIME_FOLDER" ]] && FILEBOT_LABEL="ut_label=anime"
    [[ "$location" -ef "$INCOMING_MOVIES_FOLDER" ]] && FILEBOT_LABEL="ut_label=movie"
    [[ "$location" -ef "$INCOMING_TVSHOWS_FOLDER" ]] && FILEBOT_LABEL="ut_label=tv"
    [[ "$location" -ef "$INCOMING_OTHER_FOLDER" ]] && FILEBOT_LABEL="ut_label=other"
        if [[ ! "$location" -ef "$INCOMING_OTHER_FOLDER" ]] ; then
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
                    if (( $time_spent >= $idleTTL )) || [ ${ratio%\.*} -gt $RATIO ];then
                        logger "Archiving torrent with status $state, seeding time $seeding_time and ratio $ratio"
                        # ensure the files are already copied and remove the torrent+data from Transmission
                        logger "Removing seeding/idle torrent from list, included data"
                        transmission-remote -t $id -rad >> $LOGFILE 2>&1
                        [ -d /tmp/$hash ] && rm -f /tmp/$hash
                    else
                        logger "Time spent idling: $time_spent seconds out of $idleTTL: Keep seeding, cabrones!!"
                        logger "Current ratio: $ratio and max. ratio is $RATIO: Keep seeding, cabrones!!"
                    fi
                ;;
                *)
                ;;
            esac
        else
            # OTHER folder - remove torrent if finished, preserve disk data
            [[ $state =~ Stopped|Finished ]] && transmission-remote -t $id -r >> $LOGFILE 2>&1
        fi
    FILEBOT_LABEL=""
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
    myip=$( dig +timeout=1 +short -4 -t a @ns1-1.akamaitech.net    whoami.akamai.net       2>/dev/null ) ||\
    myip=$( dig +timeout=1 +short -4 -t a @resolver1.opendns.com   myip.opendns.com        2>/dev/null ) ||\
    myip=$( dig +timeout=1 +short -t txt  @ns1.google.com          o-o.myaddr.l.google.com 2>/dev/null | tr -d '"' )

    # vpn=`mmdblookup --file /opt/GeoIP/GeoLite2-Country.mmdb --ip 80.60.233.195 country iso_code| grep '"'| grep -oP '\s+"\K\w+'`
    vpn=`mmdblookup -f $GEOIP_CONF --file $GEOIP_DB --ip $myip country iso_code| grep '"'| grep -oP '\s+"\K\w+'`
    if [[ "$vpn" == "$VPN_OK" ]]
        then
        logger "Geolocated in Country: $vpn"
        srv transmission-daemon status | grep RUNNING || { srv transmission-daemon start && sleep 5 ;}
        if [ $VPN_EXT -eq 0 ]; then
            srv $VPN_SERVICE status ;
        fi
        return 0
    else
        logger "We are not in VPN!! Country: $vpn"
        logger "Trying to stop transmission..."
        srv transmission-daemon stop >> $LOGFILE 2>&1
        if [ $VPN_EXT -eq 0 ]; then
            logger "Restarting VPN..."
            srv $VPN_SERVICE restart
        fi
        return 1
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

cloud_monitor (){
# Waits for changes in cloud folders
# Downloads ONLY .torrent files to watch folders, deleting from cloud if download is successful
# Use this one for dropbox_uploader or implement your own function for other clouds
###############################################################################
    declare -A locations

    locations[$WATCH_MOVIES_FOLDER]="$CLOUD_MOVIES_FOLDER"
    locations[$WATCH_TVSHOWS_FOLDER]="$CLOUD_TVSHOWS_FOLDER"
    locations[$WATCH_ANIME_FOLDER]="$CLOUD_ANIME_FOLDER"
    locations[$WATCH_OTHER_FOLDER]="$CLOUD_OTHER_FOLDER"

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
        for loc in "${!locations[@]}";do
            watch_path="$loc"
            cloud_path="${locations[$loc]}"

            # Download files from cloud and delete afterwards
            oIFS=$IFS
            IFS=$'\n'
            cd "$loc"
            for i in $(cloud_list_parsable_torrents $cloud_path); do
                logger "Processing file: $i"
                # Download but do not delete if download fails
                cloud_download "$cloud_path/$i" $PWD >> $LOGFILE 2>&1 && cloud_delete "$cloud_path/$i" >> $LOGFILE 2>&1
            done
            IFS=$oIFS
            sleep 1
        done
        sleep $CLOUD_DOWNLOAD_INTERVAL
    done
}

file_monitor(){
# Waits for changes in watch folders
###############################################################################
    inotifywait -q -t 120 -e close_write,moved_to,modify $WATCH_MOVIES_FOLDER $WATCH_TVSHOWS_FOLDER $WATCH_ANIME_FOLDER $WATCH_OTHER_FOLDER
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
# No point in continue if vpn is not up. This should have a "max-tries" setting
while ! check_vpn; do
    logger "Waiting for the VPN to start..."
    sleep 5
    continue
done

process_torrent_queue
add_torrents
#cloud_monitor only needed if there isn't any other cloud monitor service installed and running
cloud_monitor &

logger "Entering loop..."
while true; do
    #update_geoip
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

