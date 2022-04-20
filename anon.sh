#!/bin/sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NOCOLOR='\033[0m'
DIR="`dirname $0`"

echo_success() {
	echo "${GREEN}[+] - ${@}${NOCOLOR}"
}

echo_info() {
	echo "${BLUE}[i] - ${@}${NOCOLOR}"
}

echo_warning() {
	echo "${ORANGE}/!\ - ${@}${NOCOLOR} !"
}

echo_error() {
	echo "${RED}[-] - ${@}${NOCOLOR}"
}

check_root() {
	if (($EUID != 0)); then
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

	# Go to the script's directory
	cd "$DIR"
	"$@"
}

###################### Modules

# WEB UI

webui_on() {
	if [ ! -f '.lock_webui' ]
	then
		echo 1 > '.lock_webui'
		trap 'webui_off' 2
		echo_info 'Please go to http://localhost'
		echo_info 'Web server running, press Ctrl+C to stop it...'
		php -S localhost:80 -t "$DIR/webserver" >/dev/null 2>/dev/null
	else
		echo_error 'Web server is already running'
	fi
}

webui_off() {

	# Release trap
	trap - 2

	# Kill the webserver if running
	webui_check && killall php >/dev/null 2>/dev/null

	# Remove the lock
	rm -f '.lock_webui' && \
	echo_success '\nStopped web server'

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

# TIMEZONE

timezone_on() {

	# Backup timezone settings
	if [ ! -f "$DIR/backup/timezone" ]
	then
		echo_info 'No timezone backup found, creating one'
		timedatectl show --property=Timezone --property=NTP > "$DIR/backup/timezone" && \
		echo_success 'Backed up timezone' || \
		{echo_error 'Error backing timezone, exiting'; exit 1}
	fi

	timedatectl set-ntp on && echo_success 'NTP activated'
	timedatectl set-timezone 'Etc/UTC' && echo_success 'Timezone set to UTC'
}

timezone_off() {

	# Restore timezone settings
	if [ -f "$DIR/backup/timezone" ]
	then
		echo_info 'Restoring timezone'
		source "$DIR/backup/timezone" && \
		{timedatectl set-ntp "$NTP" && echo_success 'NTP state restored' || {echo_error 'Error restoring NTP setting, exiting'; exit 1}} && \
		{timedatectl set-timezone "$Timezone" && echo_success "Timezone restored to $Timezone" || {echo_error 'Error restoring timezone, exiting'; exit 1}} && \
		rm -f "$DIR/backup/timezone"
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
	# Only change the transcient hostname
	hostname "`cat /dev/urandom | tr -cd 'a-f0-9' | head -c 10`" && echo_success 'Random hostname set'
}

hostname_off() {
	# Reset the transcient hostname to the static hostname
	hostname "`hostname -A`" && echo_success 'Static hostname set'
}

hostname_check() {
	out=1
	if [ "`hostname`" != "`hostname -A`" ]
	then
		out=0
	fi
	return $out
}

# KALITORIFY

kalitorify_on() {

	# Backup iptable rules
	if [ ! -f "$DIR/backup/iptables" ]
	then
		echo_info 'No iptables backup found, creating one'
		iptables-save > "$DIR/backup/iptables" && \
		echo_success 'Backed up iptables rules' || \
		{echo_error 'Error backing iptables rules, exiting'; exit 1}
	fi

	kalitorify --tor
}

kalitorify_off() {
	# ! TODO: cut internet connections here to prevent leaks
	kalitorify --clearnet

	# Restore iptable rules
	if [ -f "$DIR/backup/iptables" ]
	then
		echo_info 'Restoring iptables rules'
		iptables-restore < "$DIR/backup/iptables" && \
		{rm -f "$DIR/backup/iptables"; echo_success 'Restored iptables rules'} || \
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

usage
main "$@"