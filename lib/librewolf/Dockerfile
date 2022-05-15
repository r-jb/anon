# sudo docker run -v /tmp/.X11-unix:/tmp/.X11-unix -v /dev/snd:/dev/snd -v /dev/shm:/dev/shm -v /etc/machine-id:/etc/machine-id:ro -e DISPLAY=unix$DISPLAY librewolf

FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
	dirmngr \
	gnupg \
	wget \
	ca-certificates \
	--no-install-recommends \
	&& echo "deb [arch=amd64] http://deb.librewolf.net bullseye main" | tee /etc/apt/sources.list.d/librewolf.list \
	&& wget https://deb.librewolf.net/keyring.gpg -O /etc/apt/trusted.gpg.d/librewolf.gpg \
	&& apt-get update && apt-get install -y \
	apulse \
	ca-certificates \
	ffmpeg \
	librewolf \
	hicolor-icon-theme \
	libasound2 \
	libgl1-mesa-dri \
	libgl1-mesa-glx \
	libpulse0 \
	fonts-noto \
	fonts-noto-cjk \
	fonts-noto-color-emoji \
	--no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

ENV LANG C.UTF-8

COPY local.conf /etc/fonts/local.conf

#RUN echo 'pref("browser.tabs.remote.autostart", false);' >> /etc/firefox/syspref.js

COPY entrypoint.sh /usr/bin/startlibrewolf
RUN chmod +x /usr/bin/startlibrewolf

ENTRYPOINT [ "startlibrewolf", "--log", "/dev/stdout" ]
