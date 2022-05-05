#!/bin/sh

DATA_DIR='/usr/share'
PROGRAM_DIR='/usr/local/bin'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NOCOLOR='\033[0m'
DIR="`dirname $0`"

echo_success() {
	echo "${GREEN}[+] - ${@}${NOCOLOR}"
}

echo_info() {
	echo "${BLUE}[i] - ${@}${NOCOLOR}"
}

echo_error() {
	echo "${RED}[-] - ${@}${NOCOLOR}"
}

cmd_exist() {
	command -v "$1" >/dev/null 2>/dev/null
	return $?
}

install() {
	sudo apt update
	cmd_exist anon || install_anon
	cmd_exist kalitorify || install_kalitorify
}

install_package() {
	echo_info "Installing $1"
	apt install -y --no-install-recommends "$1" > /dev/null && \
	echo_success "Installed $1"
}

install_anon() {
	cmd_exist git || install_package git
	cmd_exist php || install_package php
	cmd_exist macchanger || install_package macchanger

	echo_info 'Installing anon'
	sudo git clone -q https://github.com/r-jb/anon "$DATA_DIR/anon" && \
	sudo chmod +x "$DATA_DIR/anon/anon.sh" && \
	sudo ln -sf "$DATA_DIR/anon/anon.sh" "$PROGRAM_DIR/anon"

	# Add script to sudoers to allow running sudo without prompring for password
	# Needed for the webui
	if [ "$EUID" = '0' ]
	then
		echo_info 'If you want to run the script as a regular user, consider running the install script as the user in question without sudo'
	else
		echo "$USER ALL=(root) NOPASSWD: $PROGRAM_DIR/anon" | sudo tee -a "/etc/sudoers.d/$USER"
	fi

	echo_success 'Installed anon'
	install_web_traffic_generator
}

install_kalitorify() {
	cmd_exist git || install_package git
	echo_info 'Installing Kalitorify'
	[ -e "/tmp/kalitorify" ] && sudo rm -rf "/tmp/kalitorify"
	sudo apt install -y --no-install-recommends tor curl git make && \
	sudo git clone -q https://github.com/brainfucksec/kalitorify "/tmp/kalitorify" && \
	cd "/tmp/kalitorify" && \
	sudo make install && \
	sudo rm -rf "/tmp/kalitorify" && \
	echo_success 'Installed Kalitorify'
}

install_web_traffic_generator() {
	cmd_exist git || install_package git
	cmd_exist python || install_package python
	cmd_exist pip || install_package python-pip
	sudo mkdir -p "$DATA_DIR/anon/lib"
	echo_info 'Installing web-traffic-generator'
	pip install requests && \
	sudo wget -q -O "$DATA_DIR/anon/lib/gen.py" https://raw.githubusercontent.com/ReconInfoSec/web-traffic-generator/master/gen.py && \
	echo_success 'Installed web-traffic-generator'
}

install