#!/bin/bash

export TRUEBIT_GETHPATH="/home/lash/go/src/github.com/ethereum/go-ethereum/build/geth"
export TRUEBIT_HTTPD="default"
export TRUEBIT_IPFS="systemd"
export TRUEBIT_GETHPARAMS="--datadir=/mnt/data/.ethereum-rinkeby --ws --wsaddr 0.0.0.0 --wsorigins=* --wsapi eth"
export TRUEBIT_WASM="/mnt/data/src/ext/truebit/ocaml-offchain/interpreter/wasm"
