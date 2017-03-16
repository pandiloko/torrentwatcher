FROM base/archlinux:latest

RUN pacman  --needed  --noconfirm -Sy archlinux-keyring


#RUN pacman -Syyuw --noconfirm
#RUN rm /etc/ssl/certs/ca-certificates.crt && pacman -Syyu --noconfirm --quiet 

RUN pacman-key --populate archlinux

RUN pacman -S --needed --noconfirm --quiet libx264 mesa-libgl transmission-cli libmediainfo mediainfo geoip geoip-database bind-tools openvpn git jre8-openjdk fontconfig chromaprint sudo xz gzip binutils unzip unrar grep fakeroot file cron java-openjfx wget vim

RUN rmdir /opt && useradd watcher -Umd /opt -s /bin/bash && sudo sh -c "echo \"watcher ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"
RUN echo "@daily /usr/local/bin/geoipupdate.sh" >> /var/spool/cron/root
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && echo LANG=en_US.UTF-8 >> /etc/locale.conf && locale-gen
USER watcher
WORKDIR /opt/torrentwatcher
RUN wget static.inquant.de/bashrc -O ~/.bashrc
RUN cd /tmp &&  git clone https://aur.archlinux.org/filebot.git && cd filebot && makepkg -src && sudo pacman -U --noconfirm filebot*-`uname -m`.pkg.tar.xz
COPY torrentwatcher.sh /opt/torrentwatcher
COPY dbox/ /opt/dbox
RUN ls -R /opt/
COPY geoipupdate.sh /usr/local/bin/geoipupdate.sh
RUN sudo chown -R watcher:watcher /opt

