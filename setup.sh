#!/bin/bash

# Install GeoIP to /opt/GeoIP
cd /opt
wget $(wget https://api.github.com/repos/maxmind/geoipupdate/releases/latest -qO - | jq -r '.assets[] | select (.browser_download_url | contains("linux_amd64.tar.gz")).browser_download_url') &&\
tar -zxvf geoipupdate*linux_amd64.tar.gz && rm geoipupdate*linux_amd64.tar.gz &&\
mv geoipupdate* GeoIP && echo "DatabaseDirectory /opt/GeoIP" >> GeoIP/GeoIP.conf
(crontab -l 2>/dev/null; echo "@daily /opt/GeoIP/geoipupdate -f /opt/GeoIP/GeoIP.conf" )|crontab -


#Install Filebot
curl https://raw.githubusercontent.com/filebot/plugins/master/installer/deb.sh | sh


