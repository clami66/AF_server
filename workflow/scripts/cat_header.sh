#!/usr/bin/env bash

target=$1
groupid=$2
i=$3

cat <<- xx
PFRMAT TS
TARGET $target
AUTHOR $groupid
METHOD Vanilla AlphaFold v2.2
METHOD For details see: bioinfo.ifm.liu.se/casp15/reproduce
MODEL  $i
PARENT N/A
xx
