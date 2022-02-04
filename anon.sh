#!/bin/bash

function main {
	init
	check_requirements

	case "$1" in
		start)
			clean
			start
			clean
			;;
		stop)
			clean
			stop
			clean
			exit
			;;
		restart)
			$0 stop
			$0 start
			;;
		status)
			if [ -e $pid ]; then
				printf "[i] Traffic generator is running @ pid $(cat $pid)\n"
			else
				printf "[i] Traffic generator is NOT running\n"
			fi
			info
			;;
		install)
			install
			exit
			;;
		*)
			printf "Usage: $0 {start|stop|status|restart|install}\n\n"
			esac
			exit 0
}

function init {
	if (($EUID != 0)); then
		printf "[!] Please run with root permissions\n"
		exit 1
	fi

	green='\033[0;32m'
	orange='\033[0;33m'
	red='\033[0;31m'
	nc='\033[0m'
	pid="/var/run/anon-traffic.pid"
}

function check_requirements {
	local msg="not found\n[i] Please run $0 install"

	if [ ! -d /usr/bin/nipe ]; then
		printf "[!] nipe $msg\n"
		exit 1
	fi

	if [ ! -e /usr/bin/macchanger ]; then
		printf "[!] macchanger $msg\n"
		exit 1
	fi

	if [ ! -d /usr/bin/web-traffic-generator ]; then
		printf "[!] web-traffic-generator $msg\n"
		exit 1
	fi
}

function clean {
	printf ""
}

function start {
	#macchanger
	ip link set $interface down
	macchanger -r $interface > /dev/null
	ip link set $interface up
	printf "\t$green[+]$nc Mac address\n"

	read -p "Press [enter] when the connection is back on"

	#nipe
	cd /usr/bin/nipe && \
	perl /usr/bin/nipe/nipe.pl start > /dev/null && \
	printf "\t$green[+]$nc IP address\n"

	#hostname
	hostname $(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 10) && \
	printf "\t$green[+]$nc Hostname: $(hostname)\n"

	#web-traffic-generator
	python /usr/bin/web-traffic-generator/gen.py > /dev/null 2>&1 &
	echo $! > $pid
	[ -e $pid ] && printf "\t$green[+]$nc Fake traffic\n"
}

function stop {
	#web-traffic-generator
	[ -e $pid ] && kill $(cat $pid) > /dev/null
	rm -f $pid > /dev/null
	printf "\t$red[-]$nc Fake traffic\n"

	#hostname
	hostname $(hostnamectl --static)

	#nipe
	cd /usr/bin/nipe && \
	perl nipe.pl stop > /dev/null && \
	printf "\t$red[-]$nc IP adress\n"

	#macchanger
	ip link set $interface down > /dev/null && \
	sleep 2 && \
	macchanger -p $interface > /dev/null && \
	sleep 2 && \
	ip link set $interface up > /dev/null && \
	printf "\t$red[-]$nc Mac address\n\t$red[-]$nc Hostname\n"
}

function info {
	printf "
\tHostname:    $(hostname)
\tMac address: $(cat /sys/class/net/$interface/address)
\tIP address:  $(wget -qO- https://start.parrotsec.org/ip/\n\n)"
#wget -qO- https://start.parrotsec.org/ip/
#dig @resolver1.opendns.com ANY myip.opendns.com +short
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

function exit {
	[ -e $pid ] && rm -f $pid
}

main "$1"
