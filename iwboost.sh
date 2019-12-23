#!/bin/bash

if [ ! -z "$1" ]
then
    interface="$1"
    ifconfig ${interface} down
    iw dev ${interface} set txpower fixed 3300
    iwconfig ${interface} channel 4
    iwconfig ${interface} up
    ip link set dev ${interface} up
else
    echo "Usage: $o <interface>"
fi
