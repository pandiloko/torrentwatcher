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

mypid=$$
OPTS=`getopt -o vhf --long file:,log:,log-filebot:,watch:,watch-other:,incoming:,incoming-other:,output-movies:,output-tvshows:,cloud:,cloud-other:,filebot-cmd:,cloud-cmd:,vpn:,no-vpn,verbose,help,version -n 'parse-options' -- "$@"`

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"


LOGFILE="$__dir/var/log/torrentwatcher.log"
LOGFILEBOT="$__dir/var/log/filebot.log"
PIDFILE="$__dir/var/run/torrentwatcher.pid"

INCOMPLETE_FOLDER="$__dir/incomplete/"
WATCH_MEDIA_FOLDER="$__dir/watch/media/"
WATCH_OTHER_FOLDER="$__dir/watch/other/"

INCOMING_MEDIA_FOLDER="$__dir/media/"
INCOMING_OTHER_FOLDER="$__dir/other/"

OUTPUT_MOVIES_FOLDER="$__dir/archive/movies/"
OUTPUT_TVSHOWS_FOLDER="$__dir/archive/tvshows/"

CLOUD_MEDIA_FOLDER="/launching-media/"
CLOUD_OTHER_FOLDER="/launching-other/"

FILEBOT_CMD=`type -p filebot` || FILEBOT_CMD="/opt/filebot/filebot.sh"
FILEBOT_MOVIES_FORMAT="$OUTPUT_MOVIES_FOLDER{y} {n} [{rating}]/{n} - {y} - {genres} {group}"
FILEBOT_SERIES_FORMAT="$OUTPUT_TVSHOWS_FOLDER{n}/Season {s}/{s+'x'}{e.pad(2)} - {t} {group}"
FILEBOT_ANIME_FORMAT="$OUTPUT_TVSHOWS_FOLDER{n}/Season {s}/{s+'x'}{e.pad(2)} - {t}"

CLOUD_CMD=`type -p dropbox_uploader.sh` || CLOUD_CMD="/opt/dbox/dropbox_uploader.sh"

VPN_OK=NL
VPN_EXT=0

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/root/bin"

VERSION="1.0-raging_Togusa"
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
    ( [ -e $CONFIG_FILE ] && [ -f $CONFIG_FILE ] && [ -s $CONFIG_FILE ] ) || exit 1
    tmpfile=$(mktemp /tmp/torrentwatcher.XXXXXX)
    grep -Ei '^[ ]*[a-z]+=[^[;,`()%$!#]+[ ]*$' $CONFIG_FILE > $tmpfile
    echo "Readed options from file $tmpfile:"
    cat $tmpfile

    while true; do
        read -p "Do you want to continue? [Y] / n" yn
        case $yn in
            [Yy] ) break;;
            [Nn] ) exit 1;;
            * ) echo "Please answer with y or n.";;
        esac
    done
    rm -f $tmpfile
}

readopts(){
    if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

    echo "$OPTS"
    eval set -- "$OPTS"

    while true; do
      case "$1" in
        -v | --verbose ) VERBOSE=true; shift ;;
        -h | --help ) help; exit 0 ;;
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
        --output-tvshows) OUTPUT_MOVIES_FOLDER="$2"; shift 2 ;;
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
        if [ ! -v PS1 ] ; then
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

}

#setsid myscript.sh >/dev/null 2>&1 < /dev/null &
#exec > "$logfile" 2>&1 </dev/null
# tail -fn0 logfile | awk '/pattern/ { print | "command" }'

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
    srv transmission stop >> $LOGFILE 2>&1
    rm -rf $PIDFILE
    # TODO: PROCESS KILLING NEEDS TESTING
    ############
    /bin/kill -- -0 #kill all child processes
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
    echo "`date +'%Y.%m.%d-%H:%M:%S'` [$mypid] - $1" >> $LOGFILE
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
    [[ `echo $-` =~ .*x.* ]] && set +x && restore=yes #comment/uncomment for a cleaner output when using xtrace option
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

        transmission-remote -w "$INCOMING_MEDIA_FOLDER" >> $LOGFILE 2>&1
        for i in ${WATCH_MEDIA_FOLDER}*.torrent ; do
            logger "Processing file: $i"
            transmission-remote -a "$i" -w "$INCOMING_MEDIA_FOLDER" >> $LOGFILE 2>&1
            mv "$i" "$i.added"
        done
        for i in ${WATCH_OTHER_FOLDER}*.torrent ; do
            logger "Processing file: $i"
            transmission-remote -a "$i" -w "$INCOMING_OTHER_FOLDER" >> $LOGFILE 2>&1
            mv "$i" "$i.added"
        done

}
filebot_command(){
# parameters:
#     $1-> action [copy|move|link]
#     $2-> src folder
# Determines if file is alone or in a folder because we don't want to process the whole folder
###############################################################################
    $FILEBOT_CMD -script fn:amc -non-strict --def movieFormat="$FILEBOT_MOVIES_FORMAT" seriesFormat="$FILEBOT_SERIES_FORMAT" animeFormat="$FILEBOT_ANIME_FORMAT" music=n excludeList=/var/log/amc-exclude.txt subtitles=en --log-file /var/log/amc.log --conflict auto  --log all --action $1 "$2" >> $LOGFILE 2>&1
    return $?
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
    if filebot_command copy "${INCOMING_MEDIA_FOLDER}"; then
        for id in `transmission-remote -l|sed -e '1d;$d;'|grep "100%"| tr -sd' '| cut -f2| grep -Eo '[0-9]+'`
        do
            # Copy infos into properly named lowercased variables
            extract_info $id
            if [[ "$location" -ef "$INCOMING_MEDIA_FOLDER" ]] ; then
                logger "Processing torrent with ID: $id. $state"
                case $state in
                    Stopped|Finished|Idle)
                        logger "Archiving torrent with status $state"
                        # ensure the files are already copied and remove the torrent+data from Transmission
                        logger "Removing torrent from list, included data"
                        transmission-remote -t $id -rad >> $LOGFILE 2>&1
                    ;;
                    "Seeding")
                        # Copy but don't delete torrent, we want to keep seeding until ratio is reached
                        logger "Keep seeding, cabrones"
                    ;;
                    *)
                    ;;
                esac
            fi
            # OTHER folder - remove torrent if finished, preserve disk data
            [[ "$location" -ef "$INCOMING_OTHER_FOLDER" ]] && [[ $state == Finished ]] && transmission-remote -t $id -r >> $LOGFILE 2>&1
        done
    fi
}

srv(){
# parameters:
#     $1-> service
#     $2-> action [start,stop,status,restart]
# Performs the desired action with the requested service using the appropiate call
# Some light OS detection decides if we are in docker container or FreeBSD and
# then falls back to systemd
###############################################################################

    if [ -f /.dockerenv ]; then
        #We are in container
        case $2 in 
            start|stop|restart|status)
                sudo supervisorctl $2 $1
                return
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
            start|stop|restart|status)
                sudo systemctl $2 $1
                return
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
    myip=`dig +short myip.opendns.com @resolver1.opendns.com`
    vpn=`geoiplookup $myip | cut -d":" -f2 | cut -d"," -f1 | tr -d " "`

    if [ $vpn == $VPN_OK ]
        then
        logger "Geolocated in Country: $vpn"
        if srv transmission status | grep -q STOPPED ;then  srv transmission start; fi
        if [ $VPN_EXT -eq 0 ]; then srv openvpn status ; fi
    else
        logger "We are not in VPN!! Country: $vpn"
        logger "Trying to stop transmission..."
        srv transmission stop >> $LOGFILE 2>&1
        if [ $VPN_EXT -eq 0 ]; then 
            logger "Restarting VPN..."
            srv openvpn restart
        fi
    fi
}

cloud_monitor () {
# Waits for changes in cloud folders
# Downloads ONLY .torrent files to watch folders, deleting from cloud if download is successful
# Use this one for dropbox_uploader or implement your own function for other clouds
###############################################################################
    while true
    do
        # Monitor folders for changes
        pids=""
        $CLOUD_CMD monitor $CLOUD_MEDIA_FOLDER 60 >> $LOGFILE 2>&1 &
        pids="$pids $!"
        $CLOUD_CMD monitor $CLOUD_OTHER_FOLDER 60 >> $LOGFILE 2>&1 &
        pids="$pids $!"
        for pid in $pids; do
            wait $pid
        done
        #Download files
        oIFS=$IFS
        IFS=$'\n'
        cd $WATCH_MEDIA_FOLDER
        for i in `$CLOUD_CMD list "$CLOUD_MEDIA_FOLDER" | tr -s " " | cut -d " " -f4-|grep -E "\.torrent$"`; do
            logger "Processing file: $i"
            # Download but do not delete if download fails
            $CLOUD_CMD download "$CLOUD_MEDIA_FOLDER$i" >> $LOGFILE 2>&1 && $CLOUD_CMD delete "$CLOUD_MEDIA_FOLDER$i" >> $LOGFILE 2>&1
        done
        cd $WATCH_OTHER_FOLDER
        for i in `$CLOUD_CMD list "$CLOUD_OTHER_FOLDER" | tr -s " " | cut -d" " -f4-|grep -E "\.torrent$"`; do
            logger "Processing file: $i"
            # Download but do not delete if download fails
            $CLOUD_CMD download "$CLOUD_OTHER_FOLDER$i" >> $LOGFILE 2>&1 && $CLOUD_CMD delete "$CLOUD_OTHER_FOLDER$i" >> $LOGFILE 2>&1
        done
        IFS=$oIFS
    done
}

file_monitor(){
# Waits for changes in watch folders
###############################################################################
    inotifywait -q -t 120 -e close_write,moved_to,modify $WATCH_MEDIA_FOLDER $WATCH_OTHER_FOLDER
}
logtail(){
# Parameters
#   - file to be readed or resume reading
# Just reads a file and saves readed lines in an .offset file.
# The next time resumes reading after offset
###############################################################################
    file=$1
    offset=1 #Because tail -n +offset begins ON offset line (not after) i. e. tail -n +0 == tail -n +1
    readed=0

    #file exists, is regular file and is not zero size. Else return
    ([ -e $file ] && [  -f $file ] && [ -s $file ]) || return 1

    if [ -e $file.offset ] ;then
        offset=`cat $file.offset`
    fi

    total_lines=`wc -l < $file`
    if [ $offset -gt $((total_lines+1)) ]; then
        rm -f $file.offset
        offset=1
    fi
    #while read -r line;do
    #    ((readed+=1))
    #    echo $line
    #done < <(tail -n +$offset $file)
    # A for loop to read a file is an antipattern but
    # we must use it due to a bug in FreeBSD
    for i in `tail -n +$offset $file`;do
        ((readed+=1))
        echo $i
    done
    offset=$((offset+readed))
    echo $offset > $file.offset
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
    file_monitor
    sleep 10 # Let some time to finish eventual subsequent uploads
    logger "Downloading torrent files to watched folder"
    if srv transmission status ; then
        process_torrent_queue
        add_torrents
    fi
    logger "Checking VPN"
    check_vpn
done
