#!/usr/bin/env bash



####/usr/local/bin/bash
mypid=$$

LOGFILE="/var/log/torrentwatcher.log"
LOGFILEBOT="/var/log/filebot.log"
PIDFILE="/var/run/torrentwatcher.pid"

WATCH_MEDIA_FOLDER="/media/watch/"
WATCH_OTHER_FOLDER="/media/watch_other/"


INCOMING_MEDIA_FOLDER="/media/downloads/"
INCOMING_OTHER_FOLDER="/media/things/"

OUTPUT_MOVIES_FOLDER="/media/film/"
OUTPUT_TVSHOWS_FOLDER="/media/series/"

DBOX_MEDIA_FOLDER="/launching-area/"
DBOX_OTHER_FOLDER="/launching-things/"

FILEBOT="/root/filebot/filebot.sh"
DBOX="/root/dbox/dropbox_uploader.sh"


#setsid myscript.sh >/dev/null 2>&1 < /dev/null &
#ps x -o  "%p %r %y %x %c "
# kill -TERM -- -PID
#       start-stop-daemon [option...] command

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/root/bin"



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

    # TODO: PROCESS KILLING NEEDS TESTING
    ############
    /bin/kill -- -0 #kill all child processes
    ############
    # PGID=$(ps -o pgid= $PID | grep -o [0-9]*)
    # kill -TERM -"$PGID"  # kill -15
    ############
    # killtree $@
    ############

    rm -rf $PIDFILE
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

extract_info () {
# Parameters:
#     $1 -> torrent id
# extract info from torrent and create GLOBAL variables accordingly
# variable names are lowercased and spaces replaced with underscores
###############################################################################
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
}

add_torrents (){
        oIFS=$IFS
        IFS=$'\n'
        cd $WATCH_MEDIA_FOLDER
        for i in `$DBOX list "$DBOX_MEDIA_FOLDER" | tr -s " " | cut -d" " -f4|grep -E "\.torrent$"`; do
            logger "Processing file: $i"
            $DBOX download "$DBOX_MEDIA_FOLDER$i" >> $LOGFILE 2>&1 && $DBOX delete "$DBOX_MEDIA_FOLDER$i" >> $LOGFILE 2>&1
        done

        cd $WATCH_OTHER_FOLDER
        for i in `$DBOX list "$DBOX_OTHER_FOLDER" | tr -s " " | cut -d" " -f4|grep -E "\.torrent$"`; do
            logger "Processing file: $i"
            # Download but do not delete if download fails
            $DBOX download "$DBOX_OTHER_FOLDER$i" >> $LOGFILE 2>&1 && $DBOX delete "$DBOX_OTHER_FOLDER$i" >> $LOGFILE 2>&1
            transmission-remote -a "$i" -w "$INCOMING_OTHER_FOLDER" >> $LOGFILE 2>&1
            mv $i $i.added
        done
        IFS=$oIFS
        # This one last command should not be necessary.
        # Documention says that "transmission-remote -a <torrent/url> -w <folder>" changes the folder only for the added torrent BUT in my experience it changes (sometimes?) the default download folder
        # TODO: NEEDS MORE TESTING
        transmission-remote -w "$INCOMING_MEDIA_FOLDER" >> $LOGFILE 2>&1
}
filebot_command(){
    $FILEBOT -script fn:amc -non-strict --def movieFormat="/media/film/{y} {n} [{rating}]/{n} - {y} - {genres}" seriesFormat="/media/series/{n}/{fn}" animeFormat="/media/series/{n}/Season {s}/{s+'x'}{e.pad(2)} - {t}" music=n excludeList=/var/log/amc-exclude.txt subtitles=en --log-file /var/log/amc.log --conflict auto  --log all --action $1 "$2" >> $LOGFILE 2>&1
    return $?
}
filebot_process (){
# parameters:
#     $1-> action
#     $2-> torrent id
# Determines if file is alone or in a folder because we don't want to process the whole folder
#
# TODO:
#    on a second thought...
#    Now that we have a separate folder for non-video files we could process the whole video folder each time and reduce complexity, couldn't we?
###############################################################################

    # Pick any of the files and obtain the main folder
    folder="`transmission-remote -t $2 -f | tail -n1 | cut -d ' ' -f13- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`"
    # Go up in directory tree until getting "."

    parent=`dirname "$folder"`
    while [ "$parent" != "." ]
    do
        folder=$parent
        parent=`dirname "$folder"`
    done
    if [ ! -z "$folder" ] && [ "$folder" == "." ] ; then
        oIFS=$IFS
        IFS=$'\n'
        for file in "`transmission-remote -t $2 -f | tail -n +3 | cut -wf8-`"
        do
            filebot_command $1 "${INCOMING_MEDIA_FOLDER}${file}"
            ret=$?
        done
        IFS=$oIFS
    else
        filebot_command $1 "${INCOMING_MEDIA_FOLDER}${folder}"
        ret=$?
    fi
    return $ret
}
process_torrent_queue (){
# Collects torrents with 100% Download and process them depending on State.
# Stopped | Finished | Idle -> ensure files are copied and REMOVE FROM TRANSMISSION INCLUDING DATA
# Seeding -> copy file and let it be until ratio is reached
###############################################################################
    for id in `transmission-remote -l|sed -e '1d;$d;'|grep "100%"| cut -wf2| grep -Eo '[0-9]+'`
    do
        # Copy infos into properly named lowercased variables
        set +x #comment/uncomment for a cleaner output when using xtrace option
        extract_info $id
        set -x #comment/uncomment for a cleaner output when using xtrace option

        if [[ "${location%/}" == "${INCOMING_MEDIA_FOLDER%/}" ]] ; then
            logger "Processing torrent with ID: $id. $state"
            case $state in
                Stopped|Finished|Idle)
                    logger "Archiving torrent with status $state"
                    # ensure the files are already copied and remove the torrent+data from Transmission
                    filebot_process copy $id
                    if [ $? -eq 0 ]; then
                        logger "Removing torrent from list, included data"
                        transmission-remote -t $id -rad >> $LOGFILE 2>&1
                    fi
                ;;
                "Seeding")
                    # Copy but don't delete torrent, we want to keep seeding until ratio is reached
                    filebot_process copy $id
                ;;
                *)
                ;;
            esac
        fi
    done
    #chmod -R 777 $MOVEDIR/*
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

    if [ $vpn == "NL" ]
        then
        logger "We are in VPN!! Country: $vpn"
        service transmission status >> $LOGFILE 2>&1
        #TODO: ensure that transmission is still up and running
    else
        logger "We are not in VPN!! Country: $vpn"
        logger "Trying to stop transmission"
        #logger "`service transmission stop`"
        service transmission status >> $LOGFILE 2>&1
    fi
}

dropbox_monitor () {
# Waits for changes in dropbox folders
# Use this with dropbox_uploader
###############################################################################
    pids=""
    $DBOX monitor $DBOX_MEDIA_FOLDER 30 >> $LOGFILE 2>&1 &
    pids="$pids $!"
    $DBOX monitor $DBOX_OTHER_FOLDER 30 >> $LOGFILE 2>&1 &
    pids="$pids $!"
    for pid in $pids; do
        wait $pid
    done
}

file_monitor(){
# Waits for changes in dropbox folders
# Use this if you have dropbox daemon installed and running
###############################################################################
    inotifywait -qqr -e close_write,move,delete,create $DBOX_MEDIA_FOLDER $DBOX_OTHER_FOLDER
}

################################
# EXECUTION STARTS HERE
###############################

if ls $PIDFILE &>/dev/null; then
    if ps aux | grep `cat $PIDFILE` &>/dev/null ;then
        logger "TorrenWatcher is already running (`cat $PIDFILE`)"
        exit 0
    fi
    logger "There was a PID file but no corresponding process was running. "
fi

logger "Starting TorrentWatcher..."
echo $mypid > $PIDFILE
trap finish EXIT
process_torrent_queue
add_torrents

while true
do
    #Use only one of both monitors
    dropbox_monitor
    #file_monitor

    sleep 10 # Let some time to finish eventual subsequent uploads

    logger "Downloading torrent files to watched folder"
    process_torrent_queue
    add_torrents
    logger "Checking VPN"
    check_vpn
done
