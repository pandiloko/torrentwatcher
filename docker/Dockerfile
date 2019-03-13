FROM base/archlinux:latest

##Install packages
#########################
#RUN pacman -Syyuw --noconfirm
#RUN rm /etc/ssl/certs/ca-certificates.crt && pacman -Syyu --noconfirm --quiet 

RUN pacman  --needed  --noconfirm -Sy archlinux-keyring && \
    pacman-key --populate archlinux && \
    echo "PKGEXT='.pkg.tar'" >> /etc/makepkg.conf && echo "SRCEXT='.src.tar'" >> /etc/makepkg.conf &&\
    pacman -Syy  && pacman -S --needed --noconfirm --quiet awk base-devel bc bind-tools binutils chromaprint cron cronie fakeroot file fontconfig geoip geoip-database git grep gzip inotify-tools iproute iputils libmediainfo libx264 mediainfo mesa-libgl mlocate net-tools openvpn procps-ng sudo supervisor transmission-cli unrar unzip vim wget which xz yajl &&\
    paccache -ruk0 && pacman -Scc --noconfirm && rm -rf /var/cache/pacman/pkg/* 
# Filebot is an AUR package and must be installed with non-root user. See below after USER command

##Entry point
#########################
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
# It copies all opt contents if folder is empty.
# It will perform the copy on docker creation only or if files are deleted from host 
# See at the end of this file for more details
ENTRYPOINT ["/entrypoint.sh"]

##Network
#########################
#Expose transmission web interface and p2p ports
EXPOSE 9091 51413/tcp 51413/udp
RUN echo 'OPTARGS="--log-append /opt/torrentwatcher/log/openvpn.log"' >> /etc/default/openvpn
# RUN echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.d/99-sysctl.conf
# RUN echo 'net.core.wmem_max = 4194304' >> /etc/sysctl.d/99-sysctl.conf


##Everything else
#########################
RUN rmdir /opt && useradd watcher -Umd /opt -s /bin/bash && sudo sh -c "echo \"watcher ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers" &&\
    echo "@daily /usr/local/bin/geoipupdate.sh" >> /var/spool/cron/root && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && echo LANG=en_US.UTF-8 >> /etc/locale.conf && locale-gen

USER watcher

RUN cd /tmp && git clone https://aur.archlinux.org/package-query.git && cd package-query && makepkg -si --noconfirm &&\
	cd /tmp && git clone https://aur.archlinux.org/yaourt.git && cd yaourt && makepkg -si --noconfirm &&\
	yaourt -S --noconfirm filebot47 &&\
	sudo paccache -ruk0 && sudo pacman -Scc --noconfirm && yaourt -Scc --noconfirm && sudo rm -rf /var/cache/pacman/pkg/* /tmp/*

WORKDIR /opt/
RUN git clone https://github.com/pandiloko/torrentwatcher.git &&\
	ln -s /opt/torrentwatcher/geoipupdate.sh /usr/local/bin/geoipupdate.sh

RUN sudo ln -s /opt/torrentwatcher.ini /etc/supervisor.d/torrent.ini &&\
    sudo /usr/local/bin/geoipupdate.sh &&\
    wget static.pandiloko.com/bashrc -O ~/.bashrc && \
    sudo chown -R watcher:watcher /opt/ && \
    cd /opt/vpn &&  l=( *ovpn ) && cp ${l[0]} user.ovpn  && \
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
