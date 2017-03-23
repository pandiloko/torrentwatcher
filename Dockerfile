FROM base/archlinux:latest

##Install packages
#########################
RUN pacman  --needed  --noconfirm -Sy archlinux-keyring
#RUN pacman -Syyuw --noconfirm
#RUN rm /etc/ssl/certs/ca-certificates.crt && pacman -Syyu --noconfirm --quiet 
RUN pacman-key --populate archlinux
RUN pacman -Syy  && pacman -S --needed --noconfirm --quiet libx264 mesa-libgl transmission-cli libmediainfo mediainfo geoip geoip-database bind-tools openvpn git jre8-openjdk fontconfig chromaprint sudo xz gzip binutils unzip unrar grep fakeroot file cron java-openjfx wget vim iputils net-tools supervisor
# Filebot is an AUR package and must be installed with non-root user. See below

##Entry point
#########################
# Sorry, hash does not play well with multiline-single-quoted-dollar echo, thus the ugly 2-step echo
RUN echo '#!/bin/bash' > /entrypoint.sh
RUN echo $'content=$(find "/opt" -maxdepth 0 -type d -empty 2>/dev/null)\n\
[ -n "$content" ] && sudo cp -rfu /tmp/opt / && sudo chown -R watcher:watcher /opt\n\
exec "$@"' >> /entrypoint.sh
RUN chmod 755 /entrypoint.sh
# ENTRYPOINT is defined over. It copies all opt contents if folder is empty. 
# It will perform the copy on docker creation only or if files are deleted from host 
ENTRYPOINT ["/entrypoint.sh"]

##Process Management
#########################
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]

##Network
#########################
#Expose transmission web interface and p2p ports
EXPOSE 9091 51413/tcp 51413/udp

##Everything else
#########################
RUN rmdir /opt && useradd watcher -Umd /opt -s /bin/bash && sudo sh -c "echo \"watcher ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"
RUN echo "@daily /usr/local/bin/geoipupdate.sh" >> /var/spool/cron/root
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && echo LANG=en_US.UTF-8 >> /etc/locale.conf && locale-gen

USER watcher
RUN wget static.inquant.de/bashrc -O ~/.bashrc

RUN cd /tmp &&  git clone https://aur.archlinux.org/filebot.git && cd filebot && makepkg -src && sudo pacman -U --noconfirm filebot*-`uname -m`.pkg.tar.xz

WORKDIR /opt/
COPY torrentwatcher.sh /opt/torrentwatcher
COPY dbox/ /opt/dbox
COPY geoipupdate.sh /usr/local/bin/geoipupdate.sh
COPY vpn/ /opt/vpn
RUN sudo chown -R watcher:watcher /opt/


# I want /opt to be a host mapped folder. The problem is that we already have some files created there
# Since docker doesn't copy files on host mapping, I move all files to /tmp and the entrypoint copies 
# everything back if original directory is empty. 
# Save a copy of everything in /tmp
RUN sudo mv /opt/ /tmp/opt