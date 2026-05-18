update_geoip() {
    logger "Checking if geoip DB update is necessary"
    if [ "$(find "$GEOIP_DB" -mmin +300 | wc -l)" -gt 0 ]; then
        logger "Updating geoip DB"
        geoipupdate -f "$GEOIP_CONF"
        touch "$GEOIP_DB"
    else
        logger "geoip DB is still recent. No update necessary"
        logger "Geoip DB file: $(ls -lh "$GEOIP_DB")"
    fi
}
