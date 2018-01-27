#!/bin/bash

GETH_PID=""
GETH=`which geth` || (>&2 echo "cannot find geth binary" && exit 1)

function eth_kill {
	if [ -n "$1" ]; then
		>&2 echo "error: $1"		
	fi
	geth_stop
	exit 1
}

function geth_stop {
	if [ -n $GETH_PID ]; then
		>&2 echo "sending TERM to geth ($GETH_PID)"
		kill -TERM $GETH_PID
	fi
}

# take the newest key if none is given
function latest_key {
	echo -n `find $1/keystore -regex ".*--[a-fA-F0-9].*" | sort -r | head -n1 | sed -e 's/.*Z--\([a-fA-F0-9]*\)$/\1/g'`
}

while test $# != 0
do 
	case "$1" in
		-d) args_d=$2; shift;; #datadir
		-a) args_a=$2; shift;; #account
		-p) args_p=$2; shift;; #p2p port
		-x) args_x=$2; shift;; #command to run after ipc is up
		-n) args_n=$2; shift;; #net
		--password-file) args_passwordfile=$2; shift;;
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

if [ "$args_a" == "new" ]; then
	echo -n xyzzy > .gethpass
	acc=`geth $GETH_NET account new --password $passwordfile` || shutdown "failed to create new account"
	GETH_ACCOUNT=${acc:10:40}
else
	GETH_ACCOUNT=${args_a:-$(latest_key $GETH_DATADIR)}
fi


GETH_PORT=${args_p:+" --port $args_p"}

geth_args=(
	--datadir	"${GETH_DATADIR}"
	--unlock	"${GETH_ACCOUNT}"
	$GETH_NET
)

function geth_ipcexec {
	if [ ! -z ${args_x} ]; then
		${args_x} ${GETH_DATADIR} ${GETH_ACCOUNT}
		exit $?
	fi
}

geth_start() {
	
	($GETH "${args[@]}" --password=$passwordfile) & 
	forked=$!

	for i in {1..5}; do
		if [ -e $GETH_DATADIR/geth.ipc ]; then
			ipcowner=`lsof -t $GETH_DATADIR/geth.ipc`
			if [ "$forked" == "$ipcowner" ]; then
				GETH_PID=$forked
				geth_ipcexec && return 0
			else
				if [ ! -z ${ipcowner} ]; then 
					>&2 echo "Process ${ipcowner} already owns the this socket, exiting..." && killswarm $!
				fi
			fi
		fi
		>&2 echo "$GETH_DATADIR/geth.ipc poll $i"
		sleep 1
	done

	>&2 echo "gave up waiting for ipc, killing geth"
	eth_kill $!
	return 1
}

#put swarm stuff below here
SWARM=$GOPATH/bin/swarm
SWARM_ETHAPI=${args_e}
