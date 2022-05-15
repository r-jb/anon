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

usage() {
	echo "Usage: anon <module> (<options>)\n"
	echo "Currently supported modules are:
	${BLUE}info${NOCOLOR} - Print system informations
	${BLUE}clean${NOCOLOR} - Clean dangerous files/apps to prevent leaks
	${BLUE}shred${NOCOLOR} <${ORANGE}path to file/directory${NOCOLOR}> - Delete documents securely
	${BLUE}mat${NOCOLOR} <${ORANGE}path to file${NOCOLOR}|${GREEN}rm${NOCOLOR} <${ORANGE}path to file${NOCOLOR}>> - Show metadata or remove them
	${BLUE}webui${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Web interface for the anon script
	${BLUE}time${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Prevent time related leaks
	${BLUE}hostname${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Randomize the hostname
	${BLUE}kalitorify${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Utility to run TOR as a system proxy
	${BLUE}wtg${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Generate fake web traffic
	${BLUE}macchanger${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Randomize the MAC address of every interface
	${BLUE}hosts${NOCOLOR} <${GREEN}start${NOCOLOR}|${RED}stop${NOCOLOR}> - Blocks tracking, ads, dangerous domains
	${BLUE}librewolf${NOCOLOR} - Anti-tracking configured browser
	"
}

main() {
	check_root
	[ ! -d "$DATA_DIR/backup" ] && mkdir "$DATA_DIR/backup"

	module="`LOWER $1`"
	option="`LOWER $2`"

	case "$module" in
		'webui'|'time'|'hostname'|'kalitorify'|'wtg'|'macchanger'|'hosts'|'system'|'decoy')

			case "$option" in

				'start')
					${module}_check
					status="$?"

					# wtg module can be restarted multiple times to increase traffic
					if [ "$status" -eq '0' ] && [ "$module" != 'wtg' ]
					then
						echo_error "Module $module is already started"
						status=1
					else
						echo_info "Starting module $module"
						${module}_on
						status="$?"
						[ "$status" -eq '0' ] && \
						echo_success "Started module $module" || \
						echo_error "Error starting module $module"
					fi

					return $status
					;;

				'stop')
					${module}_check
					status="$?"

					if [ "$status" -eq '0' ]
					then
						echo_info "Stopping module $module"
						${module}_off
						status="$?"
						[ "$status" -eq '0' ] && \
						echo_success "Stopped module $module" || \
						echo_error "Error stopping module $module"
					else
						echo_error "Module $module is already stopped"
					fi

					return $status
					;;

				'')
					${module}_check
					status="$?"

					[ "$status" -eq '0' ] && \
					echo_success "Module $module is active" || \
					echo_warning "Module $module is not active"
					return $status
					;;

				*) usage
			esac
			;;

		'info'|'clean'|'shred'|'mat'|'librewolf')
			shift 1
			$module "$@"
			;;

		*) usage
	esac
}

###################### Modules

# INFORMATIONS

info() {
	echo "Hostname: `hostname`"
	echo "Timezone: `timedatectl show --property=Timezone --value`"
	echo "IP address: `curl -s https://check.torproject.org | grep 'Your IP address appears to be:' | cut -f 3 -d '>' | cut -f 1 -d '<'`"
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
			echo_error 'File/Directory not found'
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

# METADATA

mat() {
	out=1
	option_or_file="$1"
	file="$2"
	filename="`basename $file`"

	case "`LOWER $option_or_file`" in
		'rm'|'remove')
			if [ -z "$file" ]
			then
				usage
			elif [ ! -f "$file" ]
			then
				echo_error 'File not found'
			else
				echo_info "Removing metadata of $filename:"
				mat2 "$file"
				status="$?"

				if [ "$status" -eq '0' ]
				then
					out=0
					extension="${filename##*.}"
					filename_without_extension="${filename%.*}"
					echo_success "Cleaned file: $filename_without_extension.cleaned.$extension"
				else
					echo_error "Error while removing metadata of `basename $file`"
				fi
			fi
			;;

		*)
			if [ -z "$option_or_file" ]
			then
				usage
			elif [ ! -f "$option_or_file" ]
			then
				echo_error 'File not found'
			else
				echo_info "Metadata of `basename $option_or_file`:"
				mat2 -s "$option_or_file" && \
				out=0 || \
				echo_error "Error while reading metadata of `basename $option_or_file`"
			fi
	esac

	return $out
}

# WEB UI

webui_on() {

	# Redirect Ctrl+C to webui_off()
	trap 'webui_off' 2

	echo_info 'Please go to http://localhost:8000'
	echo_info 'Web server running, press Ctrl+C to stop it...'
	HIDE php -S localhost:8000 -t "$DATA_DIR/webserver"
	echo
}

webui_off() {

	# Release Ctrl+C
	trap - 2

	# Kill the webserver if running
	webui_check && \
	{
		webui_process_pid="`pgrep --full \"php -S localhost:8000 -t $DATA_DIR/webserver\"`"
		HIDE kill -9 "$webui_process_pid"
	}
}

webui_check() {
	out=1
	webui_process_pid="`pgrep --full \"php -S localhost:8000 -t $DATA_DIR/webserver\"`"
	if [ ! -z "$webui_process_pid" ]
	then
		out=0
	fi
	return $out
}

# TIME

time_on() {

	# Backup time settings
	echo_info 'Creating time settings backup'
	timedatectl show --property=Timezone --property=NTP > "$DATA_DIR/backup/timezone" && \
	echo_success 'Backed up time settings' || \
	{ echo_error 'Error backing time settings, exiting'; exit 1; }

	timedatectl set-ntp on && echo_success 'NTP activated'
	timedatectl set-timezone 'Etc/UTC' && echo_success 'Timezone set to UTC'
	HIDE sysctl -w net.ipv4.tcp_timestamps=0 && echo_success 'Disabled TCP timestamps'

	time_check
}

time_off() {
	out=1

	# Restore timezone settings
	if [ -s "$DATA_DIR/backup/timezone" ]
	then

		# Exporting the values from the backup
		while IFS== read -r key value; do
			export "$key=$value"
		done < "$DATA_DIR/backup/timezone"

		{ timedatectl set-ntp "$NTP" && echo_success 'NTP state restored' || { echo_error 'Error restoring NTP setting, exiting'; exit 1; } } && \
		{ timedatectl set-timezone "$Timezone" && echo_success "Time zone restored to $Timezone" || { echo_error 'Error restoring timezone, exiting'; exit 1; } } && \
		rm -f "$DATA_DIR/backup/timezone" && \
		echo_success 'Removed time settings backup'
	elif [ -f "$DATA_DIR/backup/timezone" ] && [ ! -s "$DATA_DIR/backup/timezone" ]
	then
		echo_error 'Time zone backup found but empty, removing it'
		rm -f "$DATA_DIR/backup/timezone"
	else
		echo_error 'No time zone backup found'
	fi

	HIDE sysctl -w net.ipv4.tcp_timestamps=1 && echo_success 'Enabled TCP timestamps'

	! time_check && out=0

	return $out
}

time_check() {
	out=1
	current_timezone="`timedatectl show --property=Timezone --value`"
	current_ntp_status="`timedatectl show --property=NTP --value`"
	tcp_timestamps_status="`sysctl net.ipv4.tcp_timestamps`"
	if [ "$current_timezone" = 'Etc/UTC' ] && [ "$current_ntp_status" = 'yes' ] && [ "$tcp_timestamps_status" = 'net.ipv4.tcp_timestamps = 0' ]
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

	# Backup iptable rules
	echo_info 'Creating backup'
	iptables-save > "$DATA_DIR/backup/iptables" && \
	echo_success 'Backed up iptables rules' || \
	{ echo_error 'Error backing iptables rules, exiting'; exit 1; }

	echo_info 'Starting Kalitorify'
	HIDE kalitorify --tor
	return $?
}

kalitorify_off() {
	HIDE kalitorify --clearnet
	status="$?"

	# Restore iptables rules
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
	out=1
	curl -s https://check.torproject.org | HIDE grep 'Congratulations. This browser is configured to use Tor.' && out=0
	return $out
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

	interfaces="`ls -1 /sys/class/net | sed 's/lo//g' | sed 's/docker0//g'`"
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

# HOSTS FILE BLOCKING

hosts_on() {
	set 'https://hosts.oisd.nl' 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts'

	tmp_work_dir='/tmp/anon/hosts'
	rm -rf "$tmp_work_dir"
	mkdir -p "$tmp_work_dir"

	if [ -s '/etc/hosts.bak' ]
	then
		echo_error 'A hosts backup already exists'
	else
		count=0
		for url in "$@"; do
			[ ! -z "$url" ] && \
			echo_info "Downloading $url" && \
			curl -sS "$url" >> "$tmp_work_dir/merge" && \
			count=$((count + 1)) && \
			echo_success "Downloaded"
		done

		if [ "$count" -le '0' ]
		then
			echo_error 'No sources could be downloaded'
		else

			# Put current hosts file at the top of new hosts file
			cp '/etc/hosts' "$tmp_work_dir/new_hosts"

			# Add indicator
			echo "\n\n### HOSTS BLOCKING STARTING HERE ###\n" >> "$tmp_work_dir/new_hosts"

			# Sort uniq entries
			sort "$tmp_work_dir/merge" | uniq | sed '/^[[:blank:]]*#/d;s/#.*//' | sed '/^[[:blank:]]*127.0.0.1/d;s/127.0.0.1.*//' >> "$tmp_work_dir/new_hosts"

			# Create current hosts backup and apply new hosts
			mv '/etc/hosts' '/etc/hosts.bak' && \
			mv "$tmp_work_dir/new_hosts" '/etc/hosts' && \
			rm -rf "$tmp_work_dir"
		fi
	fi

	hosts_check
	return $?
}

hosts_off() {
	out=1

	if [ -f '/etc/hosts.bak' ] && [ ! -s '/etc/hosts.bak' ]
	then
		echo_error 'Hosts backup found but empty, removing it'
		rm -f '/etc/hosts.bak'
	elif [ -s '/etc/hosts.bak' ]
	then
		mv '/etc/hosts.bak' '/etc/hosts' && \
		out=0
	fi

	return $out
}

hosts_check() {
	out=1

	if [ -s '/etc/hosts' ] && [ -s '/etc/hosts.bak' ]
	then
		out=0
	fi

	return $out
}

# BUNDLE SYSTEM

system_on() {
	error=0
	set 'hostname' 'macchanger' 'time' 'kalitorify'

	for m in "$@"
	do
		if [ "$error" -eq '0' ]
		then
			${m}_check || \
			{
				${m}_on || error=1
			}
		else
			system_off
		fi
	done

	system_check
	status="$?"
	if [ "$status" -ne '0' ]
	then
		echo_error 'Error enabling all modules'
	fi
	return $status
}

system_off() {
	set 'hostname' 'macchanger' 'time' 'kalitorify'

	for m in "$@"
	do
		${m}_check && ${m}_off
	done

	system_check_off
	status="$?"
	if [ "$status" -ne '0' ]
	then
		echo_error 'Error enabling all modules'
	fi
	return $status
}

# Returns true if all the system modules are active
system_check() {
	out=1

	hostname_check && \
	macchanger_check && \
	time_check && \
	kalitorify_check && \
	out=0

	return $out
}

# Returns true if all the system modules are inactive
system_check_off() {
	out=1

	! hostname_check && \
	! macchanger_check && \
	! time_check && \
	! kalitorify_check && \
	out=0

	return $out
}

# Librewolf

librewolf() {
	container_profile_path='/root/.librewolf/anon'

	echo_info 'Browser download directory: /tmp/Downloads'

	HIDE xhost +
	HIDE docker run \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-v /dev/snd:/dev/snd \
	-v /dev/shm:/dev/shm \
	-v /etc/machine-id:/etc/machine-id:ro \
	-v /etc/machine-id:/root/machine-id:ro \
	-v /tmp/Downloads:/root/Downloads \
	-v "$DATA_DIR/lib/librewolf/profile":"$container_profile_path" \
	-e DISPLAY=$DISPLAY \
	--name anon-librewolf \
	--rm \
	librewolf --profile "$container_profile_path"
}

main "$@"