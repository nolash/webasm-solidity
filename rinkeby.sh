#!/bin/sh

me=`realpath $0`
wd=`dirname $me`
pushd $wd

. ./_common.sh

GETH=$TRUEBIT_GETHPATH
GETH_EXTRA=$TRUEBIT_GETHPARAMS
GETH_STARTPOLL="ws:127.0.0.1:8546"
. ./_geth.sh

httpd_start

echo "truebit wasm env $TRUEBIT_WASM"
geth_start

>&2 echo "have geth on pid $GETH_PID"

ipfs_start

pushd $wd/node
node setup.js rinkeby.json > config.json || eth_kill "cant setup"
node app.js || eth_kill "cant app"
popd
popd
