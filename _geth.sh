#!/bin/bash

GETH_PID=""
if [ -z $GETH ]; then
	GETH=`which geth` || (>&2 echo "cannot find geth binary" && exit 1)
fi

eth_kill() {
	if [ -n "$1" ]; then
		>&2 echo "error: $1"		
	fi
	geth_stop $2
	exit 1
}

geth_stop() {
	local gethpid=""
	if [ "$1" != "" ]; then
		gethpid="$1"
	elif [ "$GETH_PID" != "" ]; then
		gethpid=$GETH_PID
	fi
	if [ "$gethpid" != "" ]; then
		ps h -p $gethpid &> /dev/null
		if [ $? == 0 ]; then
			>&2 echo "sending TERM to geth ($gethpid)"
			kill -TERM $gethpid
		fi
	fi
}

# take the newest key if none is given
latest_key() {
	echo -n `find $1/keystore -regex ".*--[a-fA-F0-9].*" | sort -r | head -n1 | sed -e 's/.*Z--\([a-fA-F0-9]*\)$/\1/g'`
}

while test $# != 0
do 
	case "$1" in
		-d) args_d=$2; shift;; #datadir
		-a) args_a=$2; shift;; #account
		-p) args_p=$2; shift;; #p2p port
		-n) args_n=$2; shift;; #net
		-x) args_x=$2; shift;; #extra args
		--password-file) args_passwordfile=$2; shift;;
		--ipcrun) args_ipcrun=$2; shift;; #command to run after ipc is up
		*) break;;
	esac
	shift
done

case "$args_n" in
	"rinkeby"|"dev"|"testnet")
		GETH_NET="--$args_n"
		;;
	"ropsten")
		GETH_NET="--testnet"
		;;
	*)
		GETH_NET=""
esac
		
GETH_DATADIR=${args_d:-~/.ethereum}

if [ ! -d $GETH_DATADIR ]; then
	>&2 echo "Datadir $GETH_DATADIR does not exist"
	exit 1
fi

passwordfile=${args_passwordfile:-".gethpass"}


GETH_PORT=${args_p:+" --port $args_p"}

geth_ipcexec() {
	if [ ! -z ${args_ipcrun} ]; then
		${args_ipcrun} ${GETH_DATADIR} ${GETH_ACCOUNT}
		exit $?
	fi
}

geth_start() {

	if [ "$args_a" == "new" ]; then
		echo -n xyzzy > $passwordfile
		local datadir=${GETH_DATADIR:-"--datadir $GETH_DATADIR"}
		local acc=`$GETH --datadir $datadir account new --password $passwordfile` || shutdown "failed to create new account"
		GETH_ACCOUNT=${acc:10:40}
	else
		GETH_ACCOUNT=${args_a:-$(latest_key $GETH_DATADIR)}
	fi

	local geth_args=(
		--datadir	"${GETH_DATADIR}"
		--unlock	"${GETH_ACCOUNT}"
		$GETH_NET
		$GETH_EXTRA
		$args_x
	)

	local startpoll=(${GETH_STARTPOLL//:/ })

	echo >&2 "running $GETH ${geth_args[@]} --password=$passwordfile"
	($GETH "${geth_args[@]}" --password=$passwordfile) & 
	forked=$!

	for i in {1..5}; do
		if [ "${startpoll[0]}" == "ws" ]; then
			>&2 echo "echo foo | nc ${startpoll[1]} ${startpoll[2]} ... poll $i"
			if `echo foo | nc ${startpoll[1]} ${startpoll[2]} &> /dev/null`; then
				GETH_PID=$forked
				geth_ipcexec && return 0
			fi
		else
			>&2 echo "$GETH_DATADIR/geth.ipc poll $i"
			if [ -e $GETH_DATADIR/geth.ipc ]; then
				ipcowner=`lsof -t $GETH_DATADIR/geth.ipc`
				if [ "$forked" == "$ipcowner" ]; then
					GETH_PID=$forked
					geth_ipcexec && return 0
				else
					if [ ! -z ${ipcowner} ]; then 
						>&2 echo "Process ${ipcowner} already owns the this socket, exiting..." && killswarm $!
					fi
					return 1
				fi
			fi
		fi
		sleep 1
	done

	eth_kill "gave up waiting for ipc, killing geth" $!
	return 1
}

#put swarm stuff below here
SWARM=$GOPATH/bin/swarm
SWARM_ETHAPI=${args_e}
