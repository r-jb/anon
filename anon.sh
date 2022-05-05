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
	echo 'Currently supported modules are:
	webui - Web interface for the anon script
	timezone - Change the timezone to UTC
	hostname - Randomize the hostname
	kalitorify - Utility to run TOR as a system proxy
	'
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
	webui_check && HIDE killall php

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
	if [ ! -s "$DATA_DIR/backup/timezone" ]
	then
		echo_info 'No timezone backup found, creating one'
		timedatectl show --property=Timezone --property=NTP > "$DATA_DIR/backup/timezone" && \
		echo_success 'Backed up timezone' || \
		{ echo_error 'Error backing timezone, exiting'; exit 1; }
	fi

	timedatectl set-ntp on && echo_success 'NTP activated'
	timedatectl set-timezone 'Etc/UTC' && echo_success 'Timezone set to UTC'
}

timezone_off() {

	# Restore timezone settings
	if [ -s "$DATA_DIR/backup/timezone" ]
	then
		echo_info 'Restoring timezone'

		# Exporting the values from the backup
		while IFS== read -r key value; do
			export "$key=$value"
		done < "$DATA_DIR/backup/timezone"

		{ timedatectl set-ntp "$NTP" && echo_success 'NTP state restored' || { echo_error 'Error restoring NTP setting, exiting'; exit 1; } } && \
		{ timedatectl set-timezone "$Timezone" && echo_success "Timezone restored to $Timezone" || { echo_error 'Error restoring timezone, exiting'; exit 1; } } && \
		echo_success 'Restored timezone from backup'
		rm -f "$DATA_DIR/backup/timezone" && \
		echo_success 'Removed backup'
	else
		echo_error 'No timezone backup found or file empty'
	fi

	# Return exit code
	timezone_check
}

timezone_check() {
	out=1
	current_timezone="`timedatectl show --property=Timezone --value`"
	current_ntp_status="`timedatectl show --property=NTP --value`"
	if [ "$current_timezone" = 'Etc/UTC' ] && [ "$current_ntp_status" = 'yes' ]
	then
		out=0
	fi
	return $out
}

timezone_cmd() {
	case "$1" in
		'on'|'start') timezone_on;;
		'off'|'stop') timezone_off;;
		*)
			timezone_check
			status="$?"

			if [ "$status" -eq '0' ]
			then
				echo_success 'Timezone module active'
			else
				echo_warning 'Timezone module is not active'
			fi
			return $status
	esac
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
	if [ ! -s "$DATA_DIR/backup/iptables" ]
	then
		echo_info 'No iptables backup found, creating one'
		iptables-save > "$DATA_DIR/backup/iptables" && \
		echo_success 'Backed up iptables rules' || \
		{ echo_error 'Error backing iptables rules, exiting'; exit 1; }
	fi

	echo_info 'Starting kalitorify'
	kalitorify --tor && \
	echo_success 'Kalitorify started'
}

kalitorify_off() {
	# ! TODO: cut off internet here to prevent leaks
	echo_info 'Starting kalitorify'
	kalitorify --clearnet

	# Restore iptable rules
	if [ -s "$DATA_DIR/backup/iptables" ]
	then
		echo_info 'Restoring iptables rules'
		iptables-restore < "$DATA_DIR/backup/iptables" && \
		{ rm -f "$DATA_DIR/backup/iptables"; echo_success 'Restored iptables rules'; } || \
		{ echo_error 'Error restoring iptables rules, exiting'; exit 1; }
	elif [ -f "$DATA_DIR/backup/iptables" ] && [ ! -s "$DATA_DIR/backup/iptables" ]
	then
		echo_error 'Iptables backup found but empty, removing it'
		rm -f "$DATA_DIR/backup/iptables"
	else
		echo_error 'No iptables backup found'
	fi

	# ! TODO: re-enable internet here to prevent leaks
}

kalitorify_restart() {
	echo_info 'Restarting kalitorify'
	kalitorify --restart && \
	echo_success 'Kalitorify restarted'
}

kalitorify_check() {
	HIDE kalitorify --status && out=0 || out=1
	return $out
}

kalitorify_cmd() {
	case "$1" in
		'on'|'start') kalitorify_on;;
		'off'|'stop') kalitorify_off;;
		'restart') kalitorify_restart;;
		*)
			kalitorify_check
			status="$?"

			if [ "$status" -eq '0' ]
			then
				echo_success 'Kalitorify is active'
			else
				echo_warning 'Kalitorify is not active'
			fi
			return $status
	esac
}

main "$@"