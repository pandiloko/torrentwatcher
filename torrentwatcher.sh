#!/usr/bin/env bash

mypid=$$

LOGFILE="/var/log/torrentwatcher.log"
LOGFILEBOT="/var/log/filebot.log"
PIDFILE="/var/run/torrentwatcher.pid"
CHANGESLOG="/tmp/torrentwatcher-changes.log"

WATCH_MEDIA_FOLDER="/media/watch/"
WATCH_OTHER_FOLDER="/media/watch_other/"

INCOMING_MEDIA_FOLDER="/media/downloads/"
INCOMING_OTHER_FOLDER="/media/things/"

OUTPUT_MOVIES_FOLDER="/media/film/"
OUTPUT_TVSHOWS_FOLDER="/media/series/"

DBOX_MEDIA_FOLDER="/launching-area/"
DBOX_OTHER_FOLDER="/launching-things/"

FILEBOT="/root/filebot/filebot.sh"
FILEBOT_MOVIES_FORMAT="$OUTPUT_MOVIES_FOLDER{y} {n} [{rating}]/{n} - {y} - {genres} {group}"
FILEBOT_SERIES_FORMAT="$OUTPUT_TVSHOWS_FOLDER{n}/Season {s}/{s+'x'}{e.pad(2)} - {t} {group}"
FILEBOT_ANIME_FORMAT="$OUTPUT_TVSHOWS_FOLDER{n}/Season {s}/{s+'x'}{e.pad(2)} - {t}"

DBOX="/root/dbox/dropbox_uploader.sh"

#setsid myscript.sh >/dev/null 2>&1 < /dev/null &
#exec > "$logfile" 2>&1 </dev/null
#ps x -o  "%p %r %y %x %c "
# kill -TERM -- -PID
#       start-stop-daemon [option...] command


# tail -fn0 logfile | \
# while read line ; do
#         echo "$line" | grep "pattern"
#         if [ $? = 0 ]
#         then
#                 ... do something ...
#         fi
# done

# tail -fn0 logfile | awk '/pattern/ { print | "command" }'

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
    rm -rf $CHANGESLOG
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
        oIFS=$IFS
        IFS=$'\n'
        shopt -s nocaseglob #Just in case, ignore case :)

        transmission-remote -w "$INCOMING_MEDIA_FOLDER" >> $LOGFILE 2>&1
        for i in `ls -1 ${WATCH_MEDIA_FOLDER}*.torrent 2>/dev/null`; do
            logger "Processing file: $i"
            transmission-remote -a "$i" -w "$INCOMING_OTHER_FOLDER" >> $LOGFILE 2>&1
            mv $i $i.added
        done

        transmission-remote -w "$INCOMING_MEDIA_FOLDER" >> $LOGFILE 2>&1
        for i in `ls -1 ${WATCH_OTHER_FOLDER}*.torrent 2>/dev/null`; do
            logger "Processing file: $i"
            transmission-remote -a "$i" -w "$INCOMING_OTHER_FOLDER" >> $LOGFILE 2>&1
            mv $i $i.added
        done

        shopt -u nocaseglob
        IFS=$oIFS
}
filebot_command(){
    $FILEBOT -script fn:amc -non-strict --def movieFormat="$FILEBOT_MOVIES_FORMAT" seriesFormat="$FILEBOT_SERIES_FORMAT" animeFormat="$FILEBOT_ANIME_FORMAT" music=n excludeList=/var/log/amc-exclude.txt subtitles=en --log-file /var/log/amc.log --conflict auto  --log all --action $1 "$2" >> $LOGFILE 2>&1
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
    folder="`transmission-remote -t $2 -f | tail -n1 | sed -E 's/.*[0-9.]+ [kgmbKGMB]+[ ]+//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`"
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
# TODO: implement Idle timeout.
    for id in `transmission-remote -l|sed -e '1d;$d;'|grep "100%"| cut -wf2| grep -Eo '[0-9]+'`
    do
        # Copy infos into properly named lowercased variables
        extract_info $id
        if [[ "$location" -ef "$INCOMING_MEDIA_FOLDER" ]] ; then
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
        # OTHER folder - remove torrent if finished, preserve disk data
        [[ "$location" -ef "$INCOMING_OTHER_FOLDER" ]] && [[ $state == Finished ]] && transmission-remote -t $id -r >> $LOGFILE 2>&1
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

cloud_monitor () {
# Waits for changes in dropbox folders
# Downloads .torrent files ONLY, deleting from Dropbox if download is successful
# Use this with dropbox_uploader or implement your own function for other clouds
###############################################################################
    while true
    do
        # Monitor folders for changes
        pids=""
        $DBOX monitor $DBOX_MEDIA_FOLDER 60 >> $LOGFILE 2>&1 &
        pids="$pids $!"
        $DBOX monitor $DBOX_OTHER_FOLDER 60 >> $LOGFILE 2>&1 &
        pids="$pids $!"
        for pid in $pids; do
            wait $pid
        done
        #Download files
        oIFS=$IFS
        IFS=$'\n'
        cd $WATCH_MEDIA_FOLDER
        for i in `$DBOX list "$DBOX_MEDIA_FOLDER" | tr -s " " | cut -d " " -f4-|grep -E "\.torrent$"`; do
            logger "Processing file: $i"
            # Download but do not delete if download fails
            $DBOX download "$DBOX_MEDIA_FOLDER$i" >> $LOGFILE 2>&1 && $DBOX delete "$DBOX_MEDIA_FOLDER$i" >> $LOGFILE 2>&1
        done
        cd $WATCH_OTHER_FOLDER
        for i in `$DBOX list "$DBOX_OTHER_FOLDER" | tr -s " " | cut -d" " -f4-|grep -E "\.torrent$"`; do
            logger "Processing file: $i"
            # Download but do not delete if download fails
            $DBOX download "$DBOX_OTHER_FOLDER$i" >> $LOGFILE 2>&1 && $DBOX delete "$DBOX_OTHER_FOLDER$i" >> $LOGFILE 2>&1
        done
        IFS=$oIFS
    done
}

file_monitor(){
# Waits for changes in dropbox folders
# Use this if you have dropbox daemon installed and running
###############################################################################
    # inotifywait -m -o $CHANGESLOG -e close_write,moved_to,modify $WATCH_MEDIA_FOLDER $WATCH_OTHER_FOLDER
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
#Execute dropbox monitor in background only if you do not have already Dropbox official monitor
cloud_monitor &

logger "Entering loop..."
while true
do
    file_monitor
    sleep 10 # Let some time to finish eventual subsequent uploads
    logger "Downloading torrent files to watched folder"
    process_torrent_queue
    add_torrents
    logger "Checking VPN"
    check_vpn
done
