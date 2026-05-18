srv() {
    local ret

    if [ -f /.dockerenv ]; then
        case $2 in
            start | stop | restart)
                sudo supervisorctl "$2" "$1"
                return $?
                ;;
            status)
                ret=$(sudo supervisorctl status "$1" 2>/dev/null | grep -w STOPPED || true)
                { [[ $ret == *STOPPED* ]] && return 1; } || return 0
                ;;
            *)
                return 1
                ;;
        esac
    elif uname -a | grep -qi freebsd; then
        case $2 in
            start | stop | restart | status)
                sudo service "$1" "$2"
                return
                ;;
            *)
                return 1
                ;;
        esac
    else
        case $2 in
            start | stop | restart)
                sudo systemctl "$2" "$1"
                return $?
                ;;
            status)
                ret=$(sudo systemctl is-active "$1")
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
