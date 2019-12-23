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

function prompt_user() {
    eval "${2}=\$(bash -c 'read -r -p \"    ${_orange}${_bold}*${_reset} ${_blue}${1}${_reset} ${_green}: \" input ; echo \${input}')"
}

function is_root() {
  if [[ "${EUID}" -ne 0 ]]
  then
  	die "This script must be run as root. Use sudo."
  fi
}

function create_temporary_directory() {
	local prefix="results"
	local suffix="_XXXXXXXXXX"

	if [ ! -z $1 ]
	then
		prefix=$1
	fi

	local temporary_directory="$(mktemp -q -d "${TMPDIR:-/tmp}/${prefix}${suffix}")" || {
		die "Unable to create temporary folder. Aborting."
	}

	echo ${temporary_directory}
}

function create_temporary_file() {
	local temporary_directory=$(create_temporary_directory)
	local temporary_file

	if [ -d ${temporary_directory} ]
	then
		local prefix="results"
		local suffix="_XXXXXXXXXX"
		local extension=""

		if [ ! -z $1 ]
		then
			prefix=$1
		fi

		if [ ! -z $2 ]
		then
			extension=".$2"
		fi

		temporary_file=$(mktemp -p ${temporary_directory} -q "${prefix}${suffix}${extension}") || {
			die "Unable to create temporary file. Aborting."
		}
	fi

	echo ${temporary_file}
}

function array_length() {
    local array_length=0

    if [ ! -z "$1" ]
    then
		local arr=$1
        array_length=${#arr[@]}
    fi

    echo ${array_length}
}

function kill_process() {
    local match="$1"

    if [ ! -z "${match}" ]
    then
        print_info "Killing process(es) matching: ${match} ..."
        killall $name
        pkill -9 -e -f $name

        for pid in `sudo ps aux | /usr/bin/grep nmap | /usr/bin/grep -v kill | cut -d ' ' -f 6`
        do
            kill -9 $pid
            print_success "[KILLED] #${pid}"
        done
    fi
}

function error_exit() {
    print_error "$@" 1>&2

    return 1
}

STDOUT="/dev/stdout"


function interface_exists() {
    local exists="0"
    local error=$(test -d /sys/class/net/$1/device ; echo $?)

    # if any error => exists
    if [ $error -eq 0 ]
    then
        exists=1
    fi

    echo $exists;
}

function interface_is_physical() {
    local is_physical="0"
    local exists=$(interface_exists "$1")

    if [ $exists -eq 1 ]
    then
        local is_wireless=$(interface_is_wireless "$1")
        # if not wireless and exists => physical
        if [ $is_wireless -eq 0 ]
        then
            is_physical=1
        fi
    fi
    echo $is_physical;
}

function interface_is_wireless() {
    local is_wireless=0
    local exists=$(interface_exists "$1")

    if [ $exists -eq 1 ]
    then
        local error=$(grep -qs 'DEVTYPE=wlan' /sys/class/net/$1/uevent ; echo $?)
        # if any error => wireless
        if [ $error -eq 0 ]
        then
            is_wireless=1
        fi
    fi
    echo $is_wireless;
}

function get_default_interface() {
    local default_interface=$(ip -o -4 route show to default | awk '/dev/ {print $5}')

    echo "${default_interface}"
}

function get_interfaces() {
    local interface
    local interfaces=($(ip link show | grep -v link | awk {'print $2'} | sed 's/://g' | grep -v lo))

    for interface in `echo ${interfaces[@]}`
    do
        echo -e "${interface}"
    done
}

function get_interfaces_up() {
    local interface
    local interfaces_up=$(ip -family inet -oneline link show scope global | grep -i 'state UP' |  sed 's/\://g' | awk '{ printf "%s\n", $2}')

    for interface in `echo ${interfaces_up[@]}`
    do
        echo "${interface}"
    done
}

function get_interfaces_down() {
    local interface
    local interfaces_down=$(ip -family inet -oneline link show scope global | grep -i 'state DOWN' | sed 's/\://g' | awk '{ printf "%s\n", $2}')

    for interface in `echo ${interfaces_down[@]}`
    do
        echo "${interface}"
    done
}

function get_interfaces_connected() {
    local interface
    local interfaces_connected=$(ip -oneline addr show scope global | awk '{ printf "%s\n", $2}')

    for interface in `echo ${interfaces_connected[@]}`
    do
        echo "${interface}"
    done
}

function get_physical_interfaces() {
    local physical_interfaces
    local interface
    local interfaces=$(get_interfaces)

    for interface in ${interfaces}
    do
        local is_physical=$(interface_is_physical ${interface})
        if [ $is_physical -eq 1 ]
        then
            physical_interfaces+="${interface}"
        fi
    done

    echo $physical_interfaces
}

function get_wireless_interfaces() {
    local wireless_interfaces
    local interface
    local interfaces=$(get_interfaces)

    for interface in ${interfaces}
    do
        local is_wireless=$(interface_is_wireless ${interface})
        if [ $is_wireless -eq 1 ]
        then
            wireless_interfaces+="${interface}"
        fi
    done

    echo $wireless_interfaces
}

function get_interface_driver() {
    local driver=$(basename $(readlink /sys/class/net/$1/device/driver))

	echo $driver
}

function get_interface_bus() {
    local device="/sys/class/net/$1/device"
    local hwinfo="${device}/modalias"
    local bus=$(cut -d ":" -f 1 "$hwinfo" 2>${STDOUT})

    echo $bus
}

function interface_is_pci() {
    local interface_is_pci=0
    local bus=$(get_interface_bus "$1")

    if [ -d /sys/bus/pci -o -d /sys/bus/pci_express -o -d /proc/bus/pci ]
    then
        if [ "${bus}" == "pci" ] || [ "${bus}" == "pcmcia" ] || [ "${bus}" == "sdio" ]
        then
            interface_is_pci=1
        fi
    fi

    echo $interface_is_pci
}

function interface_is_usb() {
    local interface_is_usb=0
    local interface_is_pci=$(interface_is_pci "$1")
    local bus=$(get_interface_bus "$1")

    if [ -d /sys/bus/usb ]
    then
        if [ $interface_is_pci -eq 0 ]
        then
            interface_is_usb=1
        fi
    fi

    echo $interface_is_usb
}

function get_interface_hardware() {
    local hardware
    local device="/sys/class/net/$1/device"
    local hwinfo="${device}/modalias"
    local bus=$(get_interface_bus "$1")

    local interface_is_pci=$(interface_is_pci "$1")
    local interface_is_usb=$(interface_is_usb "$1")

    if [ $interface_is_pci -eq 1 ]
    then
        hardware="$(cat ${device}/vendor):$(cat ${device}/device)"
    else
        if [ "${bus}" == "usb" ]
        then
            hardware="$(cut -d ":" -f 2 ${hwinfo} | cut -b 1-10 | sed 's/^.//;s/p/:/')"
        else
            hardware="$(cat "${device}/idVendor" 2>${STDOUT}):$(cat "${device}/idProduct" 2>${STDOUT})"
        fi
    fi

    local check=$(echo "$hardware" | egrep -q "^:|:$" ; echo $?)
    if [ $check -eq 0 ]
    then
        unset hardware
    else
        hardware=${hardware//0x/}
    fi

    echo "${hardware}"
}

function get_interface_chipset() {
    local chipset
    local hardware=$(get_interface_hardware "$1")
    local bus=$(get_interface_bus "$1")

    local interface_is_pci=$(interface_is_pci "$1")
    local interface_is_usb=$(interface_is_usb "$1")

    if [ ! -z "${hardware}" ]
    then
        if [ "${bus}" == "usb" ]
        then
            if [ -d /sys/bus/usb ]
            then
                chipset="$(lsusb -d ${hardware} | head -n1 - | cut -f3- -d ":" | sed 's/^....//;s/ Network Connection//g;s/ Wireless Adapter//g;s/^ //')"
            fi
        else
            if [ "${bus}" == "pci" ] || [ "${bus}" == "pcmcia" ]
            then
                if [ -d /sys/bus/pci -o -d /sys/bus/pci_express -o -d /proc/bus/pci ]
                then
                    chipset="$(lspci -d ${hardware} | cut -f3- -d ":" | sed 's/Wireless LAN Controller //g;s/ Network Connection//g;s/ Wireless Adapter//;s/^ //')"
                fi
            else
                if [ "${bus}" == "sdio" ]
                then
                    if [[ "${hardware,,}" == "0x02d0"* ]]
                    then
                        chipset=$(printf "Broadcom %d" ${hardware:7})
                    else
                        chipset="Unknown chipset for SDIO device."
                    fi
                else
                    chipset="Unknown device chipset & device bus."
                fi
            fi
        fi
    fi

    echo "${chipset}"
}

function get_interface_state() {
    local state
    local stateFile="/sys/class/net/$1/operstate"

    if [ -f "${stateFile}" ]
    then
        state=$(cat "${stateFile}")
    fi

    echo "${state}"
}

function set_interface_state() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        error=$(ip link set "$1" "$2" ; echo $?)
    fi

    return $error
}

function set_interface_up() {
    local error=1

    if [ ! -z "$1" ]
    then
        local interface="$1"
        error=$(set_interface_state "${interface}" "up" ; ip addr flush dev ${interface} ; echo $?)
    fi

    echo $error
}

function set_interface_down() {
    local error=1

    if [ ! -z "$1" ]
    then
        local interface="$1"
        error=$(set_interface_state "${interface}" "down" ; echo $?)
    fi
    echo $error
}

function set_interface_type() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        error=$(iw dev "$1" set type "$2" &> ${STDOUT} ; echo $?)
    fi

    echo $error
}

function get_interface_mode() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        error=$(iwconfig "$1" mode "$2" &> ${STDOUT} ; echo $?)
    fi

    echo $error
}

function set_interface_mode() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        error=$(iwconfig "$1" mode "$2" &> ${STDOUT} ; echo $?)
    fi

    echo $error
}

function interface_has_powersave() {
    local powersave=""

    if [ ! -z "$1" ]
    then
        local interface="$1"
        powersave=$(iw dev ${interface} get power_save | sed "s#.*:\s##gi")
    fi

    echo ${powersave}
}

function get_interface_mode() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        error=$(ip link set "$1" "$2" ; echo $?)
    fi

    return $error
}

function set_interface_txpower() {
    local country="BZ"
	local txpower=3000
	local error=1

    if [ ! -z $1 ]
    then
		error=$(iw reg set ${country})
		error=${error}$(set_interface_down "$1")
    	error=${error}$(iw ${1} set txpower fixed ${txpower})
		error=${error}$(set_interface_up "$1")
    fi

    echo "${error}"
}

function set_interface_mac() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        error=$(ip link set dev "$1" address "$2" &> ${STDOUT} ; echo $?)
    fi

    echo $error
}

function set_interface_gateway() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        error=$(ip route add default via "$1" &> ${STDOUT} ; echo $?)
    fi

    echo $error
}

function set_interface_network() {
    local error=1
    local interface_network
    local interface_netmask
    local interface_broadcast

    if [ "${#@}" -ge 1 ]
    then
		local interface="$1"
        local interface_exists=$(interface_exists "${interface}")
        
        if [ "${interface_exists}" -eq 1 ]
        then
            interface_network=$(get_interface_network "${interface}")
            interface_netmask=$(get_interface_netmask "${interface}")
            interface_broadcast=$(get_interface_broadcast "${interface}")

            prompt_user "              Network           [${interface_network}]" interface_network
            prompt_user "              Netmask           [${interface_netmask}]" interface_netmask
            prompt_user "            Broadcast           [${interface_broadcast}]" interface_broadcast
        fi
        echo "ip addr add \"${interface_network}\" broadcast \"${interface_broadcast}\" dev \"${interface}\""
        error=$(ip addr add "${interface_network}" broadcast "${interface_broadcast}" dev "${interface}" &>${STDOUT} ; echo $?)
    fi

    echo $error
}

function configure_interface() {
	local error=1

    if [ "${#@}" -eq 5 ]
    then
        error=$(set_interface_down "$1")
		error=${error}$(set_interface_mac "$1" "$2")
		error=${error}$(set_interface_up "$1")
		error=${error}$(set_interface_network $1 $3 $4)
		error=${error}$(set_interface_gateway $5)
	fi

    echo "${error}"
}

function setup_interface() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        error=$(set_interface_down "$1")
        error=${error}$(set_interface_type "$1" "$2")
        error=${error}$(set_interface_mode "$1" "$2")
        error=${error}$(set_interface_up "$1")
    fi

    echo "${error}"
}

function rename_interface() {
    local error=1

    if [ "${#@}" -eq 2 ]
    then
        local -r interface_name="$1"
        local -r interface_new_name="$2"

        local set_down_error=$(set_down "${interface_name}")
        if [ $set_down_error -ne 1 ]
        then
            error=$(ip link set ${interface_name} name ${interface_new_name} ; echo $?)
        fi
    fi

    echo $error
}

function get_interface_network() {
    local interface_network
    
    if [ ! -z "$1" ]
    then
        local interface="$1"
        interface_network=$(ip -4 addr show ${interface} | grep inet | awk {'print $2'} | head -n1 | sed "s#\.[0-9]\+/#.0/#" 2>/dev/null)
    fi

    echo ${interface_network}
}

function get_interface_address() {
    local interface_address

    if [ ! -z "$1" ]
    then
        local interface="$1"
        interface_address=$(ifconfig ${interface}  | grep -o -h -U -P 'inet\s[^0-9]*([^\s]*)' | sed "s#inet\s[^0-9]*##gi")
    fi

    echo ${interface_address}
}

function get_interface_netmask() {
    local interface_netmask

    if [ ! -z "$1" ]
    then
        local interface="$1"
        interface_netmask=$(ifconfig ${interface}  | grep -o -h -U -P 'netmask\s[^0-9]*([^\s]*)' | sed "s#netmask\s[^0-9]*##gi")
    fi

    echo ${interface_netmask}
}

function get_interface_broadcast() {
    local interface_broadcast

    if [ ! -z "$1" ]
    then
        local interface="$1"
        interface_broadcast=$(ifconfig ${interface}  | grep -o -h -U -P 'broadcast\s[^0-9]*([^\s]*)' | sed "s#broadcast\s[^0-9]*##gi")
    fi

    echo  ${interface_broadcast}
}

function get_interface_gateway() {
    local interface_gateway

    if [ ! -z "$1" ]
    then
        local interface="$1"
        interface_gateway="$(route -n | grep "${interface}" | grep "UG" | awk '{print $2}' | grep -o -h -U -P '([0-9]+\.[0-9\.]+)')"
    fi

    echo ${interface_gateway}
}

function get_interface_ssid() {
    local interface_ssid

    if [ ! -z "$1" ]
    then
        local interface="$1"
		local valid_interface=$(interface_is_wireless "${interface}")

		if [[ $valid_interface -eq 1 ]]
		then
        	interface_ssid="$(iw dev "$interface" link | awk '/SSID/ {print $NF}')"
		fi
    fi

    echo ${interface_ssid}
}

function set_access_point_state() {
	if [ "${#@}" -eq 2 ]
    then
        local -r essid="$1"
		local -r state="$2"
		local valid_interface=$(interface_is_wireless ${interface})

		if [ $valid_interface -eq 1 ]
		then
			nmcli con ${state} "${essid}"
		else
			print_error "Uknown or invalid interace: ${interface}"
		fi
	fi
}

function set_access_point_up() {
	if [ "${#@}" -eq 1 ]
    then
		set_access_point_state "$1" "up"
	fi
}

function set_access_point_down() {
	if [ "${#@}" -eq 1 ]
    then
		set_access_point_state "$1" "down"
	fi
}

function setup_access_point() {
	if [ "${#@}" -gt 1 ]
    then
        local -r interface="$1"
        local -r essid="$2"
		local valid_interface=$(interface_is_wireless ${interface})

		if [[ ${valid_interface} -eq 1 ]]
		then
			nmcli con add type wifi ifname ${interace} con-name "${essid}" autoconnect yes ssid "${essid}"
			nmcli con modify "${essid}" 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
			nmcli con modify "${essid}" wifi-sec.key-mgmt wpa-psk

			if [ ! -z $3 ]
			then
				nmcli con modify "${essid}" wifi-sec.psk "${3}"
			fi

			set_access_point_down "${essid}"
			set_access_point_up "${essid}"
		else
			print_error "Uknown or invalid interace: ${interface}"
		fi
	fi
}

function enable_port_forwarding() {
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
    sysctl -w net.ipv4.conf.all.send_redirects=0
    sysctl --system
}

function enable_transparent_proxy() {
    local proxy_interface="$1"
    local proxy_port=${2:-8080}
    
    iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port ${proxy_port}
    iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port ${proxy_port}
    ip6tables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port ${proxy_port}
    ip6tables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port ${proxy_port}
}

function display_interface_informations() {
    if [ ! -z "$1" ]
    then
        echo "[Device]"
        interface="$1"
        is_physical=$(interface_is_physical ${interface})
        is_wireless=$(interface_is_wireless ${interface})
        state=$(get_interface_state ${interface})
        driver=$(get_interface_driver ${interface})
        bus=$(get_interface_bus ${interface})
        hardware=$(get_interface_hardware ${interface})
        chipset=$(get_interface_chipset ${interface})
        
        echo "interface: $interface"
        echo "is_physical: $is_physical"
        echo "is_wireless: $is_wireless"
        echo "driver: $driver"
        echo "bus: $bus"
        echo "state: $state"
        echo "hardware: $hardware"
        echo "chipset: $chipset"
        echo ""
        
        echo "[Network]"
        ip=$(get_interface_address "${interface}")
        gateway=$(route -n | grep "${interface}" | grep "UG" | awk '{print $2}' | grep -o -h -U -P '([0-9]+\.[0-9\.]+)')
        mask=$(get_interface_netmask "${interface}")
        broadcast=$(get_interface_broadcast "${interface}")

        echo "interface: $interface"
        echo "gateway: $gateway"
        echo "ip: $ip"
        echo "netmask: $mask"
        echo "broadcast: $broadcast"
        echo ""

    else
        print_error "display_interface_informations()" "Any network inerface specified ."
    fi
}


function get_system_boot_mode() {
    local boot_mode

    if [ -d /sys/firmware/efi ]
    then
        boot_mode="UEFI"
    else
        boot_mode="BIOS"
    fi

    echo ${boot_mode}
}

function get_system_os_variable() {
    local variable_value=0

    if [ ! -z "$1" ]
    then
        local variable="$1"
        local variable_line_exists="$(cat /etc/os-release | grep -qs "^${variable}=" ; echo $?)"

        if [[ ${variable_line_exists} -eq 0 ]]
        then
            variable_value=$(cat /etc/os-release | grep -i "^${variable}=" | sed "s#^${variable}=##gi" | sed 's#"##gi')
        fi
    fi

    echo ${variable_value}
}

function get_system_os_vendor() {
    local os_vendor=0

    if [ -f "/etc/redhat-release" ]
    then
        if [ -f "/etc/fedora-release" ]
        then
            os_vendor="fedora"
        else
            os_vendor="redhat"
        fi
    else
        if [ -f "/etc/arch-release" ]
        then
            os_vendor="arch"
        else
            os_vendor="unknown"
        fi
    fi

    echo ${os_vendor}
}

function get_system_arch() {
    echo $(arch)
}

function get_system_os_type() {
    echo $(get_system_os_variable "ID")
}

function get_system_os_platform_id() {
    echo $(get_system_os_variable "PLATFORM_ID" | sed "s#platform:##gi")
}

function get_system_os_name() {
    echo $(get_system_os_variable "NAME")
}

function get_system_os_pretty_name() {
    echo $(get_system_os_variable "PRETTY_NAME")
}

function get_system_os_version() {
    echo $(get_system_os_variable "VERSION")
}

function get_system_os_version_id() {
    echo $(get_system_os_variable "VERSION_ID")
}

function get_last_kernel_version() {
    local system_os_vendor=$(get_system_os_vendor)
    local last_kernel_version=0

    if [ "${system_os_vendor}" == "redhat" ] || [ "${system_os_vendor}" == "fedora" ]
    then
        last_kernel_version=$(rpm -qa kernel | sort -V | tail -n 1)
    fi

    echo ${last_kernel_version}
}

function get_running_kernel_version() {
    local running_kernel_version="kernel-$(uname -r)"

    echo ${running_kernel_version}
}

function is_redhat() {
    local package_manager_path
    
    if [[ "$(which dnf 1>$STDOUT 2>$STDOUT ; echo $?)" -eq 0 ]]
    then
        package_manager_path=$(which dnf)
    else
        if [[ "$(which yum 1>$STDOUT 2>$STDOUT ; echo $?)" -eq 0 ]]
        then
            package_manager_path=$(which yum)
        fi
    fi
    
    if [ ! -z $package_manager_path ]
    then
        export PACKAGE_MANAGER="${package_manager_path}"
        export PACKAGE_MANAGER_INSTALL="${package_manager_path} install -y"
        export PACKAGE_MANAGER_REMOVE="${package_manager_path} remove -y"
    fi
}

function is_archlinux() {
    local package_manager_path
    
    if [[ "$(which pacman 1>$STDOUT 2>$STDOUT ; echo $?)" -eq 0 ]]
    then
        package_manager_path=$(which pacman)
    fi
    
    if [ ! -z $package_manager_path ]
    then
        export PACKAGE_MANAGER="${package_manager_path}"
        export PACKAGE_MANAGER_INSTALL="${package_manager_path} -S --noconfirm"
        export PACKAGE_MANAGER_REMOVE="${package_manager_path} -Rs"
    fi
}

function is_debian() {
    local package_manager_path
    
    if [[ "$(which apt-get 1>$STDOUT 2>$STDOUT ; echo $?)" -eq 0 ]]
    then
        package_manager_path=$(which apt-get)
    fi
    
    if [ ! -z $package_manager_path ]
    then
        export PACKAGE_MANAGER="${package_manager_path}"
        export PACKAGE_MANAGER_INSTALL="${package_manager_path} install -y"
        export PACKAGE_MANAGER_REMOVE="${package_manager_path} remove -y"
    fi
}

function detect_package_manager() {
    if [ -f "/etc/redhat-release" ]
    then
        is_redhat
    else
        if [ -f "/etc/arch-release" ]
        then
            is_archlinux
        else
            is_debian
        fi
    fi
}

function create_desktop_entry() {
    local application_name="$1"
    local application_launch_command="$2"
    local application_graphical="$3"
    local application_category="$4"
    local application_icon="$5"
    local desktop_file_path=${HOME}/.local/share/applications/minecraft.desktop
    local application_terminal
    local application_icon

    if [ ! -z "${application_graphical}" ]
    then
        case ${application_graphical} in
            true|TRUE|True|1)
                application_terminal="false"
            ;;
            *)
                application_terminal="true"
            ;;
        esac
    fi

    cat > ${desktop_file_path} <<EOF
[Desktop Entry]
Type=Application
Name=${application_name}
Comment=${application_name} launcher
Exec=${application_launch_command}
Icon=${application_icon:-""}
Terminal=${application_terminal}
Categories=${application_category:-General};
EOF

    echo "${desktop_file_path}"
}

function create_application_wrapper() {
        local application_name="$1"
        local wrapper_path

        if [ ! -z "$2" ] && [ -f "$2" ]
        then
            local application_file_path="$2"
            local application_file_extennsion=$(basename "${application_file_path}" | cut -d '.' -f2)
            wrapper_path="${3:-"/usr/bin/${application_name}"}"
            local wrapper_application_file_path="$(dirname ${wrapper_path})/$(basename ${wrapper_path}).${application_file_extennsion}"
            cp ${application_file_path} ${wrapper_application_file_path}

            cat > ${wrapper_path} <<EOF
#!/usr/bin/bash
WRAPPER_PATH=\$(readlink -f \$0)
WRAPPER_NAME=\$(basename \${WRAPPER_PATH} | sed "s#\.[a-zA-Z0-9]{2,6}\\\$##gi")
WRAPPER_DIRECTORY=\$(dirname "\${WRAPPER_PATH}")
APPLICATION_FILE_BASE="\${WRAPPER_DIRECTORY}/\${WRAPPER_NAME}"
if  [ -d "\${WRAPPER_DIRECTORY}/lib" ] && [ -f "\${WRAPPER_DIRECTORY}/lib/\${APPLICATION_FILE_BASE}" ]
then
    \${WRAPPER_DIRECTORY}/lib/\${APPLICATION_FILE_BASE} \$@
elif [ -f "\${APPLICATION_FILE_BASE}.jar" ]
then
    java -jar \${APPLICATION_FILE_BASE}.jar \$@
elif [ -f "\${APPLICATION_FILE_BASE}.py" ]
then
    python \${APPLICATION_FILE_BASE}.py \$@
else
    print "[ERROR] \$0: missing application file ."
    exit 1
fi
EOF
        sudo chmod +x ${wrapper_path}
    fi

    echo "${wrapper_path}"
}

function install_packages() {
    local packages="$1"

    if [ -z "${PACKAGE_MANAGER}" ]
    then
        detect_package_manager
    fi

    if [ ! -z "${PACKAGE_MANAGER}" ] && [ ! -z "${PACKAGE_MANAGER_INSTALL}" ]
    then
        eval ${PACKAGE_MANAGER_INSTALL} ${packages} || print_error "error while installing: ${packages}"
    fi
}

function install_git_tool() {
    local repository_url="$1"
    local repository_name=$(echo "${repository_url}" | sed 's#.*/##g' | sed 's#\.git$##g')
    local clone_directives=""
    local temporary_directory=$(create_temporary_directory)
    local install_directory="${temporary_directory}/${repository_name}"
    local install_directives

    if [[ "${@}" -eq 2 ]]
    then
        install_directives="$2"
    elif [[ "${@}" -eq 3 ]]
    then
        clone_directives="$2"
        install_directives="$3"
    fi

    if [ ! -d "${install_directory}" ]
    then
        git clone ${clone_directives} ${repository_url} ${install_directory}
    else
        pushd ${install_directory}
        git pull
        popd
    fi

    if [ ! -z "${install_directives}" ]
    then
        pushd ${install_directory}
        eval ${install_directives}
        popd
        rm -rf ${install_directives}
    fi

    return 0
}

function install_package_file() {
    local tool_location="$1"
    local install_directory=$(create_temporary_directory)
    local filename

    if [ ! -z "${tool_location}" ]
    then
        if [[ "${tool_location}" =~ (f|ht)"tp"s?"://".* ]]
        then
            filename=$(echo "${tool_location}" | sed 's#.*/##g')
            wget "${tool_location}" -O ${install_directory}/${filename}
        elif [ -f "${tool_location}" ]
        then
            filename=$(basename "${tool_location}")
            cp ${tool_location} ${install_directory}/${filename}
        fi

        if [ -f "${install_directory}/${filename}" ]
        then
            local extension=$(echo ${filename} | sed 's#.*\.##g')
            if [ ! -z "${extension}" ]
            then
                pushd ${install_directory}
                case ${extension} in
                    rpm)	
		        print_info "RPM" "Installing package ${filename} using RPM method ."
                        rpm --upgrade ${install_directory}/${filename}
                    ;;
                    deb)	
		        print_info "DEBIAN" "Installing package ${filename} using DPKG method ."
                        dpkg -i ${install_directory}/${filename}
                    ;;
                    *)
                        print_error "UKNOWN" "Unknown file type specfied ."
                    ;;
                esac
                popd
                rm -rf ${install_directory}
            fi
        fi
    fi

    return 0
}

function install_golang() {
    install_packages "golang"

    if [ -z "$GOPATH" ]
    then
        echo "export GOPATH=\"\$HOME/go\"" >> ${HOME}/.bashrc
        echo "export PATH=\"\$GOPATH/bin:\$PATH\"" >> ${HOME}/.bashrc

        export GOPATH="${HOME}/go"
        export PATH="${GOPATH}/bin:${PATH}"
    fi

    echo ${GOPATH}
}

function install_golang_tool() {
    local repository_url=$(echo "$1" | sed 's#[a-z]\+://##gi' | sed 's#\.git$##g')
    local repository_name=$(echo "${repository_url}" | sed 's#.*/##g')
    local install_directory
    local install_directives

    if [ -z "${GOPATH}" ]
    then
        GOPATH=$(install_golang)
    fi

    if [ ! -z "${GOPATH}" ]
    then
        install_directory="${GOPATH}/src/${repository_url}"
        if [[ "${@}" -eq 2 ]]
        then
            install_directives="$2"
        fi

        if [ ! -d "${install_directory}" ]
        then
            go get ${repository_url}
        fi
    else
        print_error "Missing variable GOPATH: ${GOPATH} ."
    fi

    if [ ! -z "${install_directives}" ]
    then
        pushd ${install_directory}
        eval ${install_directives}
        popd
    fi

    return 0
}

function unlock_txpower() {
    local tx_power=${1:-25}
    local database_file=${2:-$(readlink -m $(dirname $0)"/files/db.txt")}
    local install_directory=$(create_temporary_directory)
    local crda_version=$(curl -L 'https://www.kernel.org/pub/software/network/crda/' | grep -oP 'href="crda-\K[0-9]+\.[0-9]+' | sort -t. -rn -k1,1 -k2,2 -k3,3 | head -1)
    local wireless_regdb_version=$(curl -L 'https://www.kernel.org/pub/software/network/wireless-regdb/' | grep -oP 'href="wireless-regdb-\K[0-9]+\.[0-9]+\.[0-9]+' | sort -t. -rn -k1,1 -k2,2 -k3,3 | head -1)
    
    install_packages "install pkg-config libnl-3-dev libgcrypt11-dev libnl-genl-3-dev build-essential"
    wget "https://www.kernel.org/pub/software/network/crda/crda-${crda_version}.tar.xz" -O "${install_directory}/crda-${crda_version}.tar.xz"
    wget "https://www.kernel.org/pub/software/network/wireless-regdb/wireless-regdb-${wireless_regdb_version}.tar.xz" -O "${install_directory}/wireless-regdb-${wireless_regdb_version}.tar.xz"
    
    pushd ${install_directory}
    tar xvJf crda-${crda_version}.tar.xz
    tar xvJf wireless-regdb-${wireless_regdb_version}.tar.xz
    
    #copy modified ${database_file}
    if [ -f "${database_file}" ]
    then
        sed -i -e 's#\(5250\s*-\s*5350\s*@\s*80\),\s*\(30\)#(5250 - 5350 @ 80) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(5470\s*-\s*5725\s*@\s*160\),\s*\(30\)#(5470 - 5725 @ 160) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(5725\s*-\s*5875\s*@\s*80\),\s*\(30\)#(5725 - 5875 @ 80) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(2402\s*-\s*2482\s*@\s*40\),\s*\(30\)#(2402 - 2482 @ 40) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(5170\s*-\s*5250\s*@\s*80\),\s*\(30\)#(5170 - 5250 @ 80) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(5250\s*-\s*5330\s*@\s*80\),\s*\(30\)#(5250 - 5330 @ 80) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(5490\s*-\s*5710\s*@\s*160\),\s*\(30\)#(5490 - 5710 @ 160) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(5170\s*-\s*5250\s*@\s*80\),\s*\(30\)#(5170 - 5250 @ 80) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(5250\s*-\s*5330\s*@\s*80\),\s*\(30\)#(5250 - 5330 @ 80) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(5490\s*-\s*5730\s*@\s*160\),\s*\(30\)#(5490 - 5730 @ 160) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(2400\s*-\s*2494\s*@\s*40\),\s*\(30\)#(2400 - 2494 @ 40) ('$tx_power')#g' ${database_file}
        sed -i -e 's#\(4910\s*-\s*5835\s*@\s*40\),\s*\(30\)#(4910 - 5835 @ 40) ('$tx_power')#g' ${database_file}

        cp ${database_file} wireless-regdb-${wireless_regdb_version}/db.txt
        make -j$(nproc) -C wireless-regdb-${wireless_regdb_version}
        
        #backup the old regulatory.bin and move the new file into /lib/crda
        mv /lib/crda/regulatory.bin /lib/crda/regulatory.bin.old
        mv wireless-regdb-${wireless_regdb_version}/regulatory.bin /lib/crda
        cp wireless-regdb-${wireless_regdb_version}/*.pem crda-${crda_version}/pubkeys
        
        if [ -e "/lib/crda/pubkeys/benh\@debian.org.key.pub.pem" ]
        then
            cp /lib/crda/pubkeys/benh\@debian.org.key.pub.pem crda-${crda_version}/pubkeys
        fi
        
        if [ -e "/lib/crda/pubkeys/linville.key.pub.pem" ]
        then
            cp /lib/crda/pubkeys/linville.key.pub.pem crda-${crda_version}/pubkeys
        fi
        
        #change regulatory.bin path in the Makefile
        sed -i "/REG_BIN?=\/usr\/lib\/crda\/regulatory.bin/!b;cREG_BIN?=\/lib\/crda\/regulatory.bin" crda-${crda_version}/Makefile
        
        #remove -Werror option when compiling
        sed -i "/CFLAGS += -std=gnu99 -Wall -Werror -pedantic/!b;cCFLAGS += -std=gnu99 -Wall -pedantic" crda-${crda_version}/Makefile
        
        #compile
        make clean -C crda-${crda_version}
        make -j$(nproc) -C crda-${crda_version}
        make install -C crda-${crda_version}
        
        popd
        rm -rf ${install_directory}

        #reboot
        print_info "RogueAP" "A system reboot is required to apply changes. Do you want to reboot now ? [Yes,No,Y,N]:"
        read -r reboot
        
        if [ ${reboot,,} == "y" ] || [ ${reboot,,} == "yes" ]
        then
            print_info "RogueAP" "Rebooting..."
            reboot
        elif [ ${reboot,,} == "n" ] || [ ${reboot,,} == "no" ]
        then
            print_warning "RogueAP" "You chose not to reboot. Please reboot the system manually."
        else
            print_error "RogueAP" "Invalid option. Please reboot the system manually."
        fi
    else
        print_error "RogueAP" "Missing/wrong database file (db.txt) ."
    fi
}
