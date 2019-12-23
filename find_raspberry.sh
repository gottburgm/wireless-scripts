#!/bin/bash
_bold=$(tput bold)
_underline=$(tput sgr 0 1)
_reset=$(tput sgr0)

_purple=$(tput setaf 171)
_red=$(tput setaf 1)
_green=$(tput setaf 76)
_orange=$(tput setaf 3)
_blue=$(tput setaf 38)

#
# HEADERS & LOGGING
#

function print_log() {
    local datetime=$(date +'%H:%M:%S')

    if [[ "${#@}" -eq 1 ]]
    then
        printf "[${_blue}${datetime}${_reset}] ${_orange}%s${_reset}\n" "${1:-""}"
    elif [[ "${#@}" -ge 2 ]]
    then
        local level="$1"
        local color="${_blue}"

        if [[ "${level}" == "SUCCESS" ]]
        then
            color="${_green}"
        elif [[ "${level}" == "WARNING" ]]
        then
            color="${_orange}"
        elif [[ "${level}" == "ERROR" ]]
        then
            color="${_red}"
        fi

        if [[ ! -z "$3" ]]
        then
            printf "[${_blue}${datetime}${_reset}] [${_underline}${color}${level}${_reset}] ${_purple}(${_reset}${_underline}${_blue}%s${_purple})${_reset}: ${_orange}%s${_reset}\n" "$2" "$3"
        else
            printf "[${_blue}${datetime}${_reset}] [${_underline}${color}${level}${_reset}] ${_orange}%s${_reset}\n" "$2"
        fi
    fi
}

function print_debug() {
    [ "$DEBUG" -eq 1 ] && $@
}

function print_header() {
    printf "\n${_bold}${_purple}==========  %s  ==========${_reset}\n" "$@"
}

function print_arrow() {
    printf "➜ $@\n"
}

function print_info() {
    print_log "INFO" "$@"
}

function print_success() {
    print_log "SUCCESS" "$@"
}

function print_error() {
    print_log "ERROR" "$@"
}

function print_warning() {
    print_log "WARNING" "$@"
}

function print_underline() {
    printf "${_underline}${_bold}%s${_reset}\n" "$@"
}

function print_bold() {
    printf "${_bold}%s${_reset}\n" "$@"
}

function print_note() {
    printf "${_underline}${_bold}${_blue}Note:${_reset}  ${_blue}%s${_reset}\n" "$@"
}

function die() {
    print_error "$@"
    exit 1
}

function find_raspberry() {
    local interfaces=$(ip link show | grep -v link | awk {'print $2'} | sed 's/://g' | grep -oP '^[ew].+')

    for interface in `echo ${interfaces}`
    do
        local interface_network=$(ip -4 addr show ${interface} | grep inet | awk {'print $2'} | head -n1 | sed "s#\.[0-9]\+/#.0/#" 2>/dev/null)
        print_info "searching raspberry on network: ${interface_network} (${interface})"
        raspberry_address=$(sudo nmap -sn --min-parallelism 50 -sP ${interface_network} | awk '/^Nmap/{ip=$NF}/B8:27:EB/{print ip}' | sed "s/[^0-9\.\:]//gi")
        
        if [ ! -z "${raspberry_address}" ]
        then
            print_success "${interface}" "Raspberry PI found: ${raspberry_address}"
        else
            print_warning "${interface}" "Any Raspberry PI on this network ."
        fi
    done
}

find_raspberry()
