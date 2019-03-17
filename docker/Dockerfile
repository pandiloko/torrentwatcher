FROM archlinux/base
##Install packages
#########################
#RUN pacman -Syyuw --noconfirm
#RUN rm /etc/ssl/certs/ca-certificates.crt && pacman -Syyu --noconfirm --quiet 

RUN pacman  --needed  --noconfirm -Sy archlinux-keyring gnupg && \
    pacman-key --refresh-keys ;\
    pacman-key --populate archlinux ;\
    echo "PKGEXT='.pkg.tar'" >> /etc/makepkg.conf && echo "SRCEXT='.src.tar'" >> /etc/makepkg.conf
RUN    pacman -Syy  && pacman -S --needed --noconfirm --quiet awk base-devel bc bind-tools binutils chromaprint cron cronie fakeroot file fontconfig git grep gzip inotify-tools iproute iputils jq libmediainfo libx264 mediainfo mesa-libgl mlocate mmdblookup net-tools pacman-contrib procps-ng sudo supervisor transmission-cli unrar unzip vim wget which xz yajl
# Filebot is an AUR package and must be installed with non-root user. See below after USER command

##Network
#########################
#Expose transmission web interface and p2p ports
EXPOSE 9091 51413/tcp 51413/udp
# RUN echo 'OPTARGS="--log-append /opt/torrentwatcher/log/openvpn.log"' >> /etc/default/openvpn
# RUN echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.d/99-sysctl.conf
# RUN echo 'net.core.wmem_max = 4194304' >> /etc/sysctl.d/99-sysctl.conf

##Everything else
#########################

RUN rmdir /opt && useradd watcher -Umd /opt -s /bin/bash && sudo sh -c "echo \"watcher ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers" &&\
    echo "@daily /opt/GeoIP/geoipupdate -f /opt/GeoIP/GeoIP.conf" >> /var/spool/cron/root && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && echo LANG=en_US.UTF-8 >> /etc/locale.conf && locale-gen

##Entry point
#########################
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
# It copies all opt contents if folder is empty.
# It will perform the copy on docker creation only or if files are deleted from host 
# See at the end of this file for more details
ENTRYPOINT ["/entrypoint.sh"]

USER watcher

RUN cd /tmp && git clone https://aur.archlinux.org/package-query.git && cd package-query && makepkg -si --noconfirm &&\
	cd /tmp && git clone https://aur.archlinux.org/yaourt.git && cd yaourt && makepkg -si --noconfirm &&\
	yaourt -S --noconfirm filebot47 &&\
	sudo pacman -Scc --noconfirm && yaourt -Scc --noconfirm  && rm -rf /tmp/*

WORKDIR /opt/
RUN git clone https://github.com/pandiloko/torrentwatcher.git &&\
    cd /opt/torrentwatcher && git checkout coldblooded && cd - &&\
    sudo ln -s /opt/torrentwatcher/geoipupdate.sh /usr/local/bin/geoipupdate.sh &&\
    wget $(wget https://api.github.com/repos/maxmind/geoipupdate/releases/latest -qO - | jq -r '.assets[] | select (.browser_download_url | contains("linux_amd64.tar.gz")).browser_download_url') &&\
    tar -zxvf geoipupdate*linux_amd64.tar.gz && rm geoipupdate*linux_amd64.tar.gz &&\
    mv geoipupdate* GeoIP && echo "DatabaseDirectory /opt/GeoIP" >> GeoIP/GeoIP.conf

RUN sudo ln -s /opt/torrentwatcher.ini /etc/supervisor.d/torrent.ini &&\
    /opt/GeoIP/geoipupdate -f /opt/GeoIP/GeoIP.conf &&\
    wget static.pandiloko.com/bashrc -O ~/.bashrc && \
    sudo chown -R watcher:watcher /opt/ && \
    mkdir -p /opt/torrentwatcher/log/  && \
    TZ=${TZ_HOST:-"/usr/share/zoneinfo/Europe/Berlin"} && \
    sudo updatedb

# I want /opt to be a host mapped folder. The problem is that we already have some files created there
# Since docker doesn't copy files on host mapping, I move all files to /tmp and the entrypoint copies 
# everything back if original directory is empty. 
# Alternatively we could initialize everything on entrypoint.sh but I like this way

# Save a copy of everything in /tmp
RUN sudo mv /opt/ /tmp/opt
CMD ["sudo" , "supervisord", "-c", "/etc/supervisord.conf"]
