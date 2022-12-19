#!/usr/bin/env bash

target=$1
server=$2
i=$3

cat <<- xx
PFRMAT TS
TARGET $target
AUTHOR $server
METHOD Vanilla AlphaFold v2.2
MODEL  $i
PARENT N/A
xx
