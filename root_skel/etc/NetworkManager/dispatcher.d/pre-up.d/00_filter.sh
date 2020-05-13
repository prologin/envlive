#!/bin/sh

device="$1"

subnet="$(ip -o a show dev "$device" scope global | awk '{ print $4 }')"

iptables -F

iptables -A OUTPUT -d "$subnet" -j ACCEPT
iptables -A OUTPUT -d 127.0.0.1/32 -j ACCEPT
iptables -P OUTPUT DROP
