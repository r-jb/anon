#!/bin/sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NOCOLOR='\033[0m'
DATA_DIR='/usr/share/anon'
HIDE='>/dev/null 2>/dev/null'

HIDE() {
	"$@" >/dev/null 2>/dev/null
}

echo_success() {
	echo "${GREEN}[+] - ${@}${NOCOLOR}"
}

echo_info() {
	echo "${BLUE}[i] - ${@}${NOCOLOR}"
}

echo_warning() {
	echo "${ORANGE}/!\ - ${@} !${NOCOLOR}"
}

echo_error() {
	echo "${RED}[-] - ${@}${NOCOLOR}"
}

check_root() {
	if [ "`id -u`" -ne '0' ]
	then
		echo_error 'Please run with root permissions'
		exit 1
	fi
}

info() {
	echo "Hostname:\t`hostname`\n"

	echo 'Mac address:'
	for iface in "/sys/class/net/"*
	do
		iface_name="`basename $iface`"
		[ "$iface_name" != 'lo' ] && echo "\t\t$iface_name: `cat $iface/address`"
	done
	echo

	echo "IP address:\t`curl -s https://check.torproject.org | grep 'Your IP address appears to be:' | cut -d '>' -f 3 | cut -f 1 -d '<'`\n"
}

usage() {
	echo "Usage: `basename $0` <module> <start|stop|help>\n"
}

main() {
	check_root

	if [ "$#" -eq '0' ]
	then
		echo menu
	else
		case "$1" in
			'webui'|'timezone'|'hostname'|'kalitorify') $1_cmd "$2";;
			*) usage
		esac
	fi
}

###################### Modules

# WEB UI

webui_on() {
	if [ ! -f '/tmp/.lock_webui' ]
	then
		echo 1 > '.lock_webui'
		trap 'webui_off' 2
		echo_info 'Please go to http://localhost'
		echo_info 'Web server running, press Ctrl+C to stop it...'
		HIDE php -S localhost:80 -t "$DATA_DIR/webserver"
	else
		echo_error 'Web server is already running'
	fi
}

webui_off() {

	# Release trap
	trap - 2

	# Kill the webserver if running
	webui_check && HIDE kill -9 php

	# Remove the lock
	rm -f '/tmp/.lock_webui' && \
	{ echo; echo_success 'Stopped web server'; }

	# Exit code 2
	exit 2
}

webui_check() {
	out=1
	php_processes="$((`ps auxww | grep 'php -S localhost:80' | wc | awk '{print $1}'` - 1))"
	if [ "$php_processes" -gt "0" ]
	then
		out=0
	fi
	return $out
}

webui_cmd() {
	case "$1" in
		'on'|'start') webui_on;;
		'off'|'stop') webui_off;;
		*)
			webui_check
			status="$?"

			if [ "$status" -eq '0' ]
			then
				echo_success 'Web server is active'
			else
				echo_warning 'Web server is not active'
			fi
			return $status
	esac
}

# TIMEZONE

timezone_on() {
	[ ! -d "$DATA_DIR/backup" ] && mkdir "$DATA_DIR/backup"

	# Backup timezone settings
	if [ ! -f "$DATA_DIR/backup/timezone" ]
	then
		echo_info 'No timezone backup found, creating one'
		timedatectl show --property=Timezone --property=NTP > "$DATA_DIR/backup/timezone" && \
		echo_success 'Backed up timezone' || \
		{echo_error 'Error backing timezone, exiting'; exit 1}
	fi

	timedatectl set-ntp on && echo_success 'NTP activated'
	timedatectl set-timezone 'Etc/UTC' && echo_success 'Timezone set to UTC'
}

timezone_off() {

	# Restore timezone settings
	if [ -f "$DATA_DIR/backup/timezone" ]
	then
		echo_info 'Restoring timezone'
		source "$DATA_DIR/backup/timezone" && \
		{timedatectl set-ntp "$NTP" && echo_success 'NTP state restored' || {echo_error 'Error restoring NTP setting, exiting'; exit 1}} && \
		{timedatectl set-timezone "$Timezone" && echo_success "Timezone restored to $Timezone" || {echo_error 'Error restoring timezone, exiting'; exit 1}} && \
		rm -f "$DATA_DIR/backup/timezone"
	else
		echo_warning 'No timezone backup found'
	fi
}

timezone_check() {
	out=1
	current_timezone="`timedatectl | grep 'Time zone:' | awk '{print $3}'`"
	if [ "$current_timezone" = 'Etc/UTC' ]
	then
		out=0
	fi
	return $out
}

# HOSTNAME

hostname_on() {
	random_name="`cat /dev/urandom | tr -cd 'a-f0-9' | head -c 10`"
	sed -i "s/127.0.1.1\t`hostnamectl status --static | tr -d ' '`/127.0.1.1\t$random_name/g" "/etc/hosts" && \
	hostname "$random_name" && \
	echo_success 'Random hostname set'
}

hostname_off() {
	# Reset the transcient hostname to the static hostname
	current_hostname="`hostnamectl status --transient | tr -d ' '`"
	static_hostname="`hostnamectl status --static | tr -d ' '`"
	sed -i "s/127.0.1.1\t$current_hostname/127.0.1.1\t$static_hostname/g" "/etc/hosts" && \
	hostname "$static_hostname" && \
	echo_success 'Static hostname set'
}

# Returns true if hostname module is running
hostname_check() {
	out=1
	if [ "`hostnamectl status --transient | tr -d ' '`" != "`hostnamectl status --static | tr -d ' '`" ]
	then
		out=0
	fi
	return $out
}

hostname_cmd() {
	case "$1" in
		'on'|'start') hostname_on;;
		'off'|'stop') hostname_off;;
		*)
			hostname_check
			status="$?"

			if [ "$status" -eq '0' ]
			then
				echo_success 'Random hostname is active'
			else
				echo_warning 'Random hostname is not active'
			fi
			return $status
	esac
}

# KALITORIFY

kalitorify_on() {
	[ ! -d "$DATA_DIR/backup" ] && mkdir "$DATA_DIR/backup"

	# Backup iptable rules
	if [ ! -f "$DATA_DIR/backup/iptables" ]
	then
		echo_info 'No iptables backup found, creating one'
		iptables-save > "$DATA_DIR/backup/iptables" && \
		echo_success 'Backed up iptables rules' || \
		{echo_error 'Error backing iptables rules, exiting'; exit 1}
	fi

	kalitorify --tor
}

kalitorify_off() {
	# ! TODO: cut internet connections here to prevent leaks
	kalitorify --clearnet

	# Restore iptable rules
	if [ -f "$DATA_DIR/backup/iptables" ]
	then
		echo_info 'Restoring iptables rules'
		iptables-restore < "$DATA_DIR/backup/iptables" && \
		{rm -f "$DATA_DIR/backup/iptables"; echo_success 'Restored iptables rules'} || \
		{echo_error 'Error restoring iptables rules, exiting'; exit 1}
	else
		echo_warning 'No iptables rules backup found'
	fi

	# ! TODO: re-enable internet connections here to prevent leaks
}

kalitorify_check() {
	out=1
	if [ "`kalitorify --status`" != "`hostname -A`" ]
	then
		out=0
	fi
	return $out
}

main "$@"