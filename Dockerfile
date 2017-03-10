FROM base/archlinux:latest

RUN pacman --noconfirm -Sy archlinux-keyring
RUN pacman -Syyu --noconfirm --quiet > /dev/null
RUN pacman-key --populate archlinux

RUN pacman -S --needed --noconfirm --quiet libx264 mesa-libgl transmission-cli libmediainfo mediainfo geoip geoip-database bind-tools openvpn git jre8-openjdk fontconfig chromaprint sudo xz gzip binutils unzip unrar grep fakeroot file

RUN rmdir /opt && useradd torrentwatcher -Umd /opt -s /bin/bash && sudo sh -c "echo \"torrentwatcher ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"

USER torrentwatcher
RUN cd /tmp &&  git clone https://aur.archlinux.org/filebot.git && cd filebot && makepkg -srci
RUN mkdir /opt/torrentwatcher
ADD torrentwatcher.sh /opt/torrentwatcher

