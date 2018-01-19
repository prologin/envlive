#!/bin/sh

device="$1"

subnet="$(ip -o a show dev "$device" scope global | awk '{ print $4 }')"

iptables -F

iptables -A OUTPUT -d "$subnet" -j ACCEPT
iptables -P OUTPUT DROP
