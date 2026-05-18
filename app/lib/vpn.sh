check_vpn() {
    local myip vpn

    myip=$(dig +timeout=10 +short -4 -t a @ns1-1.akamaitech.net whoami.akamai.net 2>/dev/null) ||
        myip=$(dig +timeout=10 +short -4 -t a @resolver1.opendns.com myip.opendns.com 2>/dev/null) ||
        myip=$(dig +timeout=10 +short -t txt @ns1.google.com o-o.myaddr.l.google.com 2>/dev/null | tr -d '"')

    vpn=$(mmdblookup -f "$GEOIP_CONF" --file "$GEOIP_DB" --ip "$myip" country iso_code | grep '"' | grep -oP '\s+"\K\w+')
    if [[ "$vpn" == "$VPN_OK" ]]; then
        logger "Geolocated in Country: $vpn"
        srv transmission-daemon status | grep RUNNING || { srv transmission-daemon start && sleep 5; }
        if [ "$VPN_EXT" -eq 0 ]; then
            srv "$VPN_SERVICE" status
        fi
        return 0
    else
        logger "We are not in VPN!! Country: $vpn"
        logger "Trying to stop transmission..."
        srv transmission-daemon stop >>"$LOGFILE" 2>&1
        if [ "$VPN_EXT" -eq 0 ]; then
            logger "Restarting VPN..."
            srv "$VPN_SERVICE" stop
            sudo route -en
            sudo /sbin/route del -net 0.0.0.0 gw "$GW"
            sudo /sbin/route add -net 0.0.0.0 gw "$GW"
            srv "$VPN_SERVICE" start
            sleep 5
        fi
        return 1
    fi
}
