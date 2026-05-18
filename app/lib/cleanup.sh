# killtree - not used. Testing only
killtree() {
    local _pid=$1
    local _sig=${2:--TERM}
    kill -stop "${_pid}"
    local _child
    for _child in $(ps -o pid --no-headers --ppid "${_pid}"); do
        killtree "${_child}" ${_sig}
    done
    kill -"${_sig}" "${_pid}"
}

stop_cloud_monitor_and_reap() {
    if [[ -n "${CLOUD_MONITOR_PID:-}" ]] && kill -0 "$CLOUD_MONITOR_PID" 2>/dev/null; then
        local pgid my_pgid
        pgid=$(ps -o pgid= -p "$CLOUD_MONITOR_PID" 2>/dev/null | tr -d ' ')
        my_pgid=$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ')
        if [[ -n "$pgid" && -n "$my_pgid" && "$pgid" != "$my_pgid" ]]; then
            kill -TERM "-$pgid" 2>/dev/null || true
        else
            kill -TERM "$CLOUD_MONITOR_PID" 2>/dev/null || true
        fi
        local w=0
        while kill -0 "$CLOUD_MONITOR_PID" 2>/dev/null && ((w < 45)); do
            sleep 1
            w=$((w + 1))
        done
        if kill -0 "$CLOUD_MONITOR_PID" 2>/dev/null; then
            if [[ -n "$pgid" && -n "$my_pgid" && "$pgid" != "$my_pgid" ]]; then
                kill -KILL "-$pgid" 2>/dev/null || true
            else
                kill -KILL "$CLOUD_MONITOR_PID" 2>/dev/null || true
            fi
        fi
        wait "$CLOUD_MONITOR_PID" 2>/dev/null || true
    elif [[ -n "${CLOUD_MONITOR_PID:-}" ]]; then
        wait "$CLOUD_MONITOR_PID" 2>/dev/null || true
    fi
    CLOUD_MONITOR_PID=""
}

stop_remaining_direct_children() {
    local pid
    local -a pids to_wait
    while IFS= read -r pid; do
        [[ -z "$pid" || "$pid" == "$$" ]] && continue
        pids+=("$pid")
    done < <(pgrep -P "$$" 2>/dev/null || true)
    [[ ${#pids[@]} -eq 0 ]] && return 0
    for pid in "${pids[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 2
    to_wait=("${pids[@]}")
    while IFS= read -r pid; do
        [[ -z "$pid" || "$pid" == "$$" ]] && continue
        kill -KILL "$pid" 2>/dev/null || true
        to_wait+=("$pid")
    done < <(pgrep -P "$$" 2>/dev/null || true)
    for pid in "${to_wait[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}

finish() {
    [[ -n "${_tw_finish_done:-}" ]] && return
    _tw_finish_done=1

    logger "Finishing TorrentWatcher. Cleaning up tasks..."
    stop_cloud_monitor_and_reap
    srv transmission-daemon stop |& tee -a "$LOGFILE"
    srv "$VPN_SERVICE" stop |& tee -a "$LOGFILE"
    sh -c "echo $$ route -en  ; exec sudo route -en"
    sh -c "echo $$ del route  ; exec sudo /sbin/route del -net 0.0.0.0 gw $GW"
    sh -c "echo $$ del route  ; exec sudo /sbin/route add -net 0.0.0.0 gw $GW"

    stop_remaining_direct_children

    rm -f "$PIDFILE"
    wait 2>/dev/null || true
}
