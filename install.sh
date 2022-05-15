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

LOWER() {
	echo "$@" | tr '[:upper:]' '[:lower:]' | tr -d ' '
}

cmd_exist() {
	command -v "$1" >/dev/null 2>/dev/null
	return $?
}

cmd_exist_or_update() {
	out=1
	cmd_exist "$1"
	status="$?"

	if [ "$status" -eq '0' ] && [ "$assume_yes" -ne '1' ]
	then
		echo -n "${BLUE}[?] - Do you want to update $1 [Y|n]: ${NOCOLOR}"
		read confirm
		case "`LOWER $confirm`" in
			'n'|'no') out=0
		esac
	fi

	return $out
}

install() {
	assume_yes=0
	case "`LOWER $1`" in
		'-y'|'-yes') assume_yes=1
	esac
	sudo apt update -qq
	cmd_exist_or_update anon || install_anon
	cmd_exist_or_update kalitorify || install_kalitorify
}

install_package() {
	echo_info "Installing $1"
	sudo apt install -y --no-install-recommends "$1" > /dev/null && \
	echo_success "Installed $1"
}

install_anon() {
	tmp_path='/tmp/anon'

	cmd_exist git || install_package git
	cmd_exist php || install_package php
	cmd_exist macchanger || install_package macchanger
	cmd_exist bleachbit || install_package bleachbit
	cmd_exist mat2 || install_package mat2

	echo_info 'Installing anon'
	[ -e "$tmp_path" ] && sudo rm -rf "$tmp_path"
	sudo git clone -q https://github.com/r-jb/anon.git "$tmp_path" && \
	sudo rsync -rauh --delete --exclude "$DATA_DIR/anon/lib/librewolf/profile" "$tmp_path" "$DATA_DIR/anon" && \
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
	install_librewolf
}

install_kalitorify() {
	tmp_path='/tmp/kalitorify'

	cmd_exist git || install_package git

	echo_info 'Installing Kalitorify'
	[ -e "$tmp_path" ] && sudo rm -rf "$tmp_path"
	sudo apt install -y --no-install-recommends tor curl git make && \
	sudo git clone -q https://github.com/brainfucksec/kalitorify.git "$tmp_path" && \
	cd "$tmp_path" && \
	sudo make install && \
	sudo rm -rf "$tmp_path" && \
	echo_success 'Installed Kalitorify'
}

install_web_traffic_generator() {
	cmd_exist git || install_package git
	cmd_exist python || install_package python
	cmd_exist pip || install_package python-pip
	echo_info 'Installing web-traffic-generator'
	pip install requests && \
	sudo wget -q -O "$DATA_DIR/anon/lib/gen.py" https://raw.githubusercontent.com/ReconInfoSec/web-traffic-generator/master/gen.py && \
	echo_success 'Installed web-traffic-generator'
}

install_librewolf() {
	cmd_exist docker || install_package docker.io
	sudo systemctl start docker && \
	sudo docker build --no-cache --pull --quiet --tag librewolf "$DATA_DIR/anon/lib/librewolf" && \
	echo_success 'Installed hardened librewolf'
}

install "$@"