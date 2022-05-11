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

LOWER() {
	echo "$@" | tr '[:upper:]' '[:lower:]' | tr -d ' '
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
	echo "Usage: anon <module> <option>\n"
	echo "Currently supported modules are:
	${BLUE}info${NOCOLOR} - Print system informations
	${BLUE}clean${NOCOLOR} - Clean dangerous files/apps to prevent leaks
	${BLUE}shred${NOCOLOR} <${ORANGE}path to file|directory${NOCOLOR}> - Shred documents securely
	${BLUE}webui${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Web interface for the anon script
	${BLUE}timezone${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Change the timezone to UTC
	${BLUE}hostname${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Randomize the hostname
	${BLUE}kalitorify${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Utility to run TOR as a system proxy
	${BLUE}wtg${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Fake web traffic generator
	${BLUE}macchanger${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Changes the MAC address of every interface
	"
}

main() {
	check_root
	[ ! -d "$DATA_DIR/backup" ] && mkdir "$DATA_DIR/backup"

	module="`LOWER $1`"
	cmd="`LOWER $2`"

	case "$module" in
		'webui'|'timezone'|'hostname'|'kalitorify'|'wtg'|'macchanger')

			case "$cmd" in

				'start')
					${module}_check
					status="$?"

					# wtg module can be restarted multiple times to increase traffic
					if [ "$status" -eq '0' ] && [ "$module" != 'wtg' ]
					then
						echo_error "Module $module is already started"
						exit 1
					else
						echo_info "Starting module $module"
						${module}_on && \
						echo_success "Started module $module" || \
						echo_error "Error starting module $module"
					fi
					;;

				'stop')
					${module}_check
					status="$?"

					if [ "$status" -eq '0' ]
					then
						echo_info "Stopping module $module"
						${module}_off && \
						echo_success "Stopping module $module" || \
						echo_error "Error stopping module $module"
					else
						echo_error "Module $module is already stopped"
						exit 1
					fi
					;;

				'')
					${module}_check
					status="$?"

					if [ "$status" -eq '0' ]
					then
						echo_success "Module $module is active"
					else
						echo_warning "Module $module is not active"
					fi
					;;

				*) usage
			esac
			;;

		'info'|'clean'|'shred') $module "$cmd";;

		*) usage
	esac
}

###################### Modules

# INFORMATIONS

info() {
	echo "Hostname: `hostname`"
	echo "Timezone: `timedatectl show --property=Timezone --value`"
	echo "IP address: "`curl -s https://check.torproject.org | grep 'Your IP address appears to be:' | cut -f 3 -d '>' | cut -f 1 -d '<'`""
	interfaces="`ls -1 /sys/class/net | sed 's/lo//g'`"
	echo -n "$interfaces\n" | while IFS= read -r iface; do echo -n "MAC address on $iface: "; macchanger --show "$iface"  | grep 'Current MAC:' | awk '{print $3}'; done
}

# CLEAN DANGEROUS APPS/FILES

clean() {

	# Kill some network app that can have sensitive data
	HIDE killall -q chrome dropbox skype icedove thunderbird firefox firefox-esr chromium xchat hexchat transmission steam firejail librewolf
	echo_success 'Dangerous applications killed'

	bleachbit --list-cleaners | \
	while read option
	do
		{
			test "${option#*history}" != "$option" || \
			test "${option#*cache}" != "$option" || \
			test "${option#*current_session}" != "$option" || \
			test "${option#*flash}" != "$option"
		} && HIDE bleachbit --clean "$option"
	done
	echo_success 'Cache and history cleaned'
}

# SHRED FILES

shred() {
	out=1
	to_shred="$1"

	if [ -z "$to_shred" ]
	then
		echo_error 'Please provide a file/directory to shred'
	else
		if [ ! -e "$to_shred" ]
		then
			echo_error 'The file/directory provided does not exist'
		else
			HIDE bleachbit --shred "$to_shred" && \
			[ ! -e "$to_shred" ] && \
			{
				out=0
				echo_success 'File securely deleted'
			} || echo_error 'Could not securely delete the files provided'
		fi
	fi

	return $out
}

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
	webui_check && killall -q php

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

# TIMEZONE

timezone_on() {

	# Remove previous backup
	[ -f "$DATA_DIR/backup/timezone" ] && rm -f "$DATA_DIR/backup/timezone"

	# Backup iptable rules
	echo_info 'Creating backup'
	timedatectl show --property=Timezone --property=NTP > "$DATA_DIR/backup/timezone" && \
	echo_success 'Backed up timezone' || \
	{ echo_error 'Error backing timezone, exiting'; exit 1; }

	timedatectl set-ntp on && echo_success 'NTP activated'
	timedatectl set-timezone 'Etc/UTC' && echo_success 'Timezone set to UTC'

	timezone_check
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
		rm -f "$DATA_DIR/backup/timezone" && \
		echo_success 'Removed backup'
	elif [ -f "$DATA_DIR/backup/timezone" ] && [ ! -s "$DATA_DIR/backup/timezone" ]
	then
		echo_error 'Timezone backup found but empty, removing it'
		rm -f "$DATA_DIR/backup/timezone"
	else
		echo_error 'No timezone backup found'
	fi

	! timezone_check
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

# KALITORIFY

kalitorify_on() {

	# Remove previous backup
	[ -f "$DATA_DIR/backup/iptables" ] && rm -f "$DATA_DIR/backup/iptables"

	# Backup iptable rules
	echo_info 'Creating backup'
	iptables-save > "$DATA_DIR/backup/iptables" && \
	echo_success 'Backed up iptables rules' || \
	{ echo_error 'Error backing iptables rules, exiting'; exit 1; }

	kalitorify --tor
}

kalitorify_off() {
	kalitorify --clearnet
	status="$?"

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

	return $status
}

kalitorify_check() {
	HIDE kalitorify --status
	return $?
}

# WEB-TRAFFIC-GENERATOR

wtg_on() {
	HIDE nohup python "$DATA_DIR/lib/gen.py" > /dev/null &
	wtg_check
}

wtg_off() {
	wtg_process_pid="`pgrep --full \"python $DATA_DIR/lib/gen.py\"`"
	echo "$wtg_process_pid" | while read -r p; do HIDE kill -9 "$p"; done
	! wtg_check
}

wtg_check() {
	out=1
	wtg_process_count="`pgrep --full \"python $DATA_DIR/lib/gen.py\" | wc -l`"
	if [ "$wtg_process_count" -gt '0' ]
	then
		out=0
	fi
	return $out
}

# MACCHANGER

macchanger_on() {

	# Remove previous backup
	[ -f "$DATA_DIR/backup/macchanger" ] && rm -f "$DATA_DIR/backup/macchanger"

	interfaces="`ls -1 /sys/class/net | sed 's/lo//g'`"
	echo "$interfaces" | while read -r iface; do
		HIDE macchanger --random "$iface" && \
		echo "$iface" >> "$DATA_DIR/backup/macchanger" && \
		echo_success "Random MAC address set on $iface"
	done

	macchanger_check
	status="$?"
	if [ "$status" -ne '0' ]
	then
		echo_error 'Could not set a random MAC address to any interface'
	fi
	return $status
}

macchanger_off() {

	# Restore interfaces MAC addresses
	if [ -s "$DATA_DIR/backup/macchanger" ]
	then
		while IFS= read -r iface; do
			HIDE macchanger --permanent "$iface" && \
			echo_success "Restored permanent MAC address on $iface" || \
			echo_error "Error restoring permanent MAC address on $iface"
		done < "$DATA_DIR/backup/macchanger"
	elif [ -f "$DATA_DIR/backup/macchanger" ] && [ ! -s "$DATA_DIR/backup/macchanger" ]
	then
		echo_error 'Macchanger backup found but empty, removing it'
		rm -f "$DATA_DIR/backup/macchanger"
	else
		echo_error 'No macchanger backup found'
	fi

	macchanger_check
	status="$?"
	if [ "$status" -ne '0' ]
	then
		rm -rf "$DATA_DIR/backup/macchanger" && \
		echo_success 'Removed macchanger backup'
	fi

	! macchanger_check
	return $?
}

macchanger_check() {
	out=0

	if [ -s "$DATA_DIR/backup/macchanger" ]
	then

		# Check that each interface in the backup has a different MAC address than its static one
		while IFS= read -r iface; do
			current_mac="`macchanger --show $iface | grep 'Current MAC:' | awk '{print $3}'`"
			permanent_mac="`macchanger --show $iface | grep 'Permanent MAC:' | awk '{print $3}'`"
			[ "$current_mac" = "$permanent_mac" ] && out=1
		done < "$DATA_DIR/backup/macchanger"
	else
		out=1
	fi

	return $out
}

main "$@"