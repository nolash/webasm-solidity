#!/bin/sh

me=`realpath $0`
wd=`dirname $me`
pushd $wd

. ./_common.sh
. ./_geth.sh

httpd_start

geth_start

>&2 echo "have geth on pid $GETH_PID"

ipfs_start

pushd $wd/node
node setup.js rinkeby.json > config.json || eth_kill "cant setup"
node app.js || eth_kill "cant app"
popd
popd
