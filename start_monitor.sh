#!/usr/bin/env bash

STDOUT="/dev/stdout"

if [ ! -z "$1" ]
then
    interface="$1"
    if [ ! -z "$2" ]
    then
        sudo airmon-ng check kill
        sudo rfkill unblock wifi
        sudo service NetworkManager stop &> ${STDOUT}
        sudo systemctl stop NetworkManager &> ${STDOUT}
        sudo rmmod iwlwifi
        sudo rmmod iwlmvm
        sudo modprobe iwlwifi 11n_disable=1
        sudo ip link set ${interface} down
        sudo iw dev ${interface} set type monitor
        sudo iwconfig ${interface} mode monitor
        sudo iw reg set BZ
        sudo iw ${interface} set txpower fixed 3600
        sudo ip link set ${interface} up
        sudo iwconfig ${interface} power off
        sudo iw ${interface} set channel 13
        # 80Mz: sudo iw ${interface} set freq 5745 80 5775
        sudo iwconfig ${interface}
    else
        sudo service NetworkManager start &> ${STDOUT}
        sudo systemctl start NetworkManager &> ${STDOUT}
    fi
else
    echo "Usage: $0 <INTERFACE>"
fi
