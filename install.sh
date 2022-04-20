#!/bin/sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NOCOLOR='\033[0m'
DIR="`dirname $0`"

echo_success() {
	echo "${GREEN}[+] - ${@}${NOCOLOR}"
}

echo_info() {
	echo "${BLUE}[i] - ${@}${NOCOLOR} !"
}

echo_error() {
	echo "${RED}[-] - ${@}${NOCOLOR}"
}

function init {
	if (($EUID != 0)); then
		echo "[!] Please run with root permissions"
		exit 1
	fi
}

function check_requirements {
	[ ! -d "$DIR/lib" ] && mkdir "$DIR/lib"

	cd "$DIR/lib"

	if [ ! -d /usr/bin/nipe ]; then
		echo "[!] nipe $msg"
		exit 1
	fi

	if [ ! -e /usr/bin/macchanger ]; then
		echo "[!] macchanger $msg"
		exit 1
	fi

	if [ ! -d /usr/bin/web-traffic-generator ]; then
		echo "[!] web-traffic-generator $msg"
		exit 1
	fi
}

function install {
	dir="/tmp/"
	cd "$dir"

	#macchanger perl python pip git
	apt update && \
	apt -y install macchanger perl python python-pip git
	apt -y autoremove

	#nipe
	git clone https://github.com/GouveaHeitor/nipe && \
	cp -a --remove-destination nipe /usr/bin/ && \
	cd /usr/bin/nipe && \
	perl nipe.pl install && \
	cpan install Switch JSON Config::Simple
	cd "$dir"

	#web-traffic-generator
	if [ -f /usr/bin/web-traffic-generator/config.py ]; then
		wget https://raw.githubusercontent.com/ReconInfoSec/web-traffic-generator/master/gen.py && \
		cp -a --remove-destination web-traffic-generator/gen.py /usr/bin/web-traffic-generator/
	else
		pip install requests && \
		git clone https://github.com/ReconInfoSec/web-traffic-generator && \
		cp -a --remove-destination web-traffic-generator /usr/bin/
	fi

	cd ~
	rm -rf "$dir"
}

install_kalitorify() {
	echo_info 'Installing Kalitorify'
	apt update && \
	apt install -y --no-install-recommends tor curl git make && \
	git clone https://github.com/brainfucksec/kalitorify && \
	cd kalitorify && \
	make install && \
	echo_success 'Installed Kalitorify'
}

install_php() {
	echo_info 'Installing PHP'
	apt update && \
	apt install -y --no-install-recommends php && \
	echo_success 'Installed PHP'
}