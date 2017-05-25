FROM base/archlinux:latest

##Install packages
#########################
#RUN pacman -Syyuw --noconfirm
#RUN rm /etc/ssl/certs/ca-certificates.crt && pacman -Syyu --noconfirm --quiet 

RUN pacman  --needed  --noconfirm -Sy archlinux-keyring && \
    pacman-key --populate archlinux && \
    pacman -Syy  && pacman -S --needed --noconfirm --quiet libx264 mesa-libgl transmission-cli libmediainfo mediainfo geoip geoip-database bind-tools openvpn git jre8-openjdk fontconfig chromaprint sudo xz gzip binutils unzip unrar grep fakeroot file cron java-openjfx wget vim iputils net-tools supervisor procps-ng mlocate which
# Filebot is an AUR package and must be installed with non-root user. See below after USER command

##Entry point
#########################
# Sorry, hash does not play well with multiline-single-quoted-dollar echo, thus the ugly 2-step echo
RUN echo '#!/bin/bash' > /entrypoint.sh && echo $'set -x \n\
content=$(find "/opt" -maxdepth 0 -type d -empty 2>/dev/null)\n\
[ -n "$content" ] && sudo cp -rfu /tmp/opt / && sudo chown -R watcher:watcher /opt\n\
exec "$@"' >> /entrypoint.sh && chmod 755 /entrypoint.sh
# ENTRYPOINT is defined over. It copies all opt contents if folder is empty.
# It will perform the copy on docker creation only or if files are deleted from host 
# See at the end of this file for more details
ENTRYPOINT ["/entrypoint.sh"]

##Process Management
#########################
COPY supervisord.conf /etc/supervisor.d/torrentwatcher.ini

##Network
#########################
#Expose transmission web interface and p2p ports
EXPOSE 9091 51413/tcp 51413/udp
RUN echo 'OPTARGS="--log-append /opt/torrentwatcher/var/log/openvpn.log"' >> /etc/default/openvpn
# RUN echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.d/99-sysctl.conf
# RUN echo 'net.core.wmem_max = 4194304' >> /etc/sysctl.d/99-sysctl.conf


##Everything else
#########################
RUN rmdir /opt && useradd watcher -Umd /opt -s /bin/bash && sudo sh -c "echo \"watcher ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers" &&\
    echo "@daily /usr/local/bin/geoipupdate.sh" >> /var/spool/cron/root && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && echo LANG=en_US.UTF-8 >> /etc/locale.conf && locale-gen

USER watcher

RUN cd /tmp &&  git clone https://aur.archlinux.org/filebot.git && cd filebot && makepkg -src && sudo pacman -U --noconfirm filebot*-`uname -m`.pkg.tar.xz

WORKDIR /opt/
COPY torrentwatcher.sh /opt/torrentwatcher/torrentwatcher.sh
COPY dbox/ /opt/dbox
COPY geoipupdate.sh /usr/local/bin/geoipupdate.sh
COPY vpn/ /opt/vpn

#COPY or ADD do not honor USER, so we must chown everything (should we change to Rocker?) 
RUN sudo /usr/local/bin/geoipupdate.sh &&\
    wget static.inquant.de/bashrc -O ~/.bashrc && \
    sudo chown -R watcher:watcher /opt/ && \
    cd /opt/vpn &&  l=( *ovpn ) && cp ${l[0]} user.ovpn  && \
    mkdir -p /opt/torrentwatcher/var/log/  && \
    TZ=${TZ_HOST:-"/usr/share/zoneinfo/Europe/Berlin"} && \
    sudo updatedb

# I want /opt to be a host mapped folder. The problem is that we already have some files created there
# Since docker doesn't copy files on host mapping, I move all files to /tmp and the entrypoint copies 
# everything back if original directory is empty. 
# Save a copy of everything in /tmp
RUN sudo mv /opt/ /tmp/opt
CMD ["sudo" , "supervisord", "-c", "/etc/supervisord.conf"]
