#!/usr/bin/env bash

target=$1
groupid=$2
i=$3

cat <<- xx
PFRMAT TS
TARGET $target
AUTHOR $groupid
METHOD Vanilla AlphaFold v2.2
METHOD Databases as downloaded by AF2 scripts (22/04/2022)
MODEL  $i
PARENT N/A
xx
