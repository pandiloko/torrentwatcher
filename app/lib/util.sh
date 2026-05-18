trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

logger() {
    echo "[torrentwatcher] $(date +'%Y.%m.%d-%H:%M:%S') [$mypid] - $1" | tee -a "$LOGFILE"
}
