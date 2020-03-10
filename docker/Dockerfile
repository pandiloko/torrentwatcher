FROM ubuntu:bionic
##Install packages
#########################
#RUN pacman -Syyuw --noconfirm
#RUN rm /etc/ssl/certs/ca-certificates.crt && pacman -Syyu --noconfirm --quiet 

RUN set -x \
	&& apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get upgrade  -y \
	&& DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends --no-upgrade -y install apt-utils perl-modules \
        && DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends --no-upgrade -y install vim net-tools bash-completion curl wget inetutils-telnet less

RUN set -x \
        && DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends --no-upgrade -y install vim net-tools bash-completion curl wget less bc dnsutils binutils cron file fontconfig git grep gzip inotify-tools jq mediainfo libx264-152 mlocate net-tools rclone sudo supervisor transmission-cli unrar unzip vim wget libmediainfo0v5 inotify-tools mmdb-bin gnupg openssl ca-certificates  \
	&& apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

#RUN curl -k "https://api.github.com/repos/maxmind/geoipupdate/releases/latest" 
RUN set -x \
	&& wget $( curl -kfs "https://api.github.com/repos/maxmind/geoipupdate/releases/latest" |  jq -r '.assets[].browser_download_url' | grep amd64.deb ) \
        && dpkg -i geoipupdate*linux_amd64.deb && rm geoipupdate*linux_amd64.deb
        # && mv geoipupdate* GeoIP && echo "DatabaseDirectory /opt/GeoIP" >> GeoIP/GeoIP.conf \
	# && (crontab -l 2>/dev/null && echo "@daily /opt/GeoIP/geoipupdate -f /opt/GeoIP/GeoIP.conf" )|crontab -


RUN set -x \
	&& echo "deb [arch=all] https://get.filebot.net/deb/ universal-jdk8 main" > /etc/apt/sources.list.d/filebot.list \
	&& curl https://get.filebot.net/filebot/KEYS | apt-key add - \
	&& apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends --no-upgrade -y install filebot \
	&& apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

RUN set -x \
	&& rmdir /opt && useradd watcher -Umd /opt -s /bin/bash && sudo sh -c "echo \"watcher ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"

##Network
#########################
#Expose transmission web interface and p2p ports
EXPOSE 9091 51413/tcp 51413/udp
# RUN echo 'OPTARGS="--log-append /opt/torrentwatcher/log/openvpn.log"' >> /etc/default/openvpn
# RUN echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.d/99-sysctl.conf
# RUN echo 'net.core.wmem_max = 4194304' >> /etc/sysctl.d/99-sysctl.conf


##Entry point
#########################
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
# It copies all opt contents if folder is empty.
# It will perform the copy on docker creation only or if files are deleted from host 
# See at the end of this file for more details
ENTRYPOINT ["/entrypoint.sh"]

USER watcher
# 
# RUN cd /tmp && git clone https://aur.archlinux.org/package-query.git && cd package-query && makepkg -si --noconfirm &&\
# 	cd /tmp && git clone https://aur.archlinux.org/yaourt.git && cd yaourt && makepkg -si --noconfirm &&\
# 	yaourt -S --noconfirm filebot47 &&\
# 	sudo pacman -Scc --noconfirm && yaourt -Scc --noconfirm  && rm -rf /tmp/*
# 
# WORKDIR /opt/
# RUN git clone https://github.com/pandiloko/torrentwatcher.git &&\
#     cd /opt/torrentwatcher && git checkout coldblooded && cd - &&\
#     sudo ln -s /opt/torrentwatcher/geoipupdate.sh /usr/local/bin/geoipupdate.sh &&\
#     wget $(wget https://api.github.com/repos/maxmind/geoipupdate/releases/latest -qO - | jq -r '.assets[] | select (.browser_download_url | contains("linux_amd64.tar.gz")).browser_download_url') &&\
#     tar -zxvf geoipupdate*linux_amd64.tar.gz && rm geoipupdate*linux_amd64.tar.gz &&\
#     mv geoipupdate* GeoIP && echo "DatabaseDirectory /opt/GeoIP" >> GeoIP/GeoIP.conf
# 
# RUN sudo ln -s /opt/torrentwatcher/torrentwatcher.ini /etc/supervisor.d/torrent.ini &&\
#     /opt/GeoIP/geoipupdate -f /opt/GeoIP/GeoIP.conf &&\
#     wget static.pandiloko.com/bashrc -O ~/.bashrc && \
#     sudo chown -R watcher:watcher /opt/ && \
#     mkdir -p /opt/torrentwatcher/log/  && \
#     TZ=${TZ_HOST:-"/usr/share/zoneinfo/Europe/Berlin"} && \
#     sudo updatedb
# 
# # I want /opt to be a host mapped folder. The problem is that we already have some files created there
# # Since docker doesn't copy files on host mapping, I move all files to /tmp and the entrypoint copies 
# # everything back if original directory is empty. 
# # Alternatively we could initialize everything on entrypoint.sh but I like this way
# 
# # Save a copy of everything in /tmp
# RUN sudo mv /opt/ /tmp/opt
CMD ["sudo" , "supervisord", "-c", "/etc/supervisord.conf"]
