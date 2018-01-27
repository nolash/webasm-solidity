#!/bin/bash

ARCH=`uname | tr "[:upper:]" "[:lower:]"`
HTTPD=${TRUEBIT_HTTPD:-"default"}
IPFS=${TRUEBIT_IPFS:-"default"}
GETHPARAMS=${TRUEBIT_GETHPARAMS:-""}

httpd_fallback() {
	service apache restart
}

ipfs_fallback() {
	ipfs daemon &
}

httpd_is_running() {
	[ -f /run/httpd/httpd.pid ]
}

ipfs_is_running() {
	ipfs status bw &> /dev/null
}

httpd_start_systemd() {
	sys=`systemctl list-unit-files | grep httpd`
	if [ -n "$sys" ]; then
		if httpd_is_running; then
			systemctl restart httpd
		else
			systemctl start httpd
		fi
		if [ $? == 0 ]; then
			HTTPD="systemd"
		fi
	fi
}

ipfs_start_systemd() {
	sys=`systemctl list-unit-files | grep ipfs`
	if [ -n "$sys" ]; then
		if ! ipfs_is_running; then
			systemctl --user start ipfs
		fi
		if [ $? == 0 ]; then
			IPFS="systemd"
		fi
	fi
}

httpd_start() {
#case $ARCH in
#	"linux")
	case $HTTPD in
		"systemd")
			#which systemctl && systemd_start
			httpd_start_systemd
			;;
		*)
			httpd_fallback
	esac
}

ipfs_start() {
	case $IPFS in
		"systemd")
			ipfs_start_systemd
			;;
		*)
			if ! ipfs_is_running; then
				ipfs_fallback
			fi
	esac
}

