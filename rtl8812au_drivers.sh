#!/bin/bash


function install_depencies() {
    install_packages "python-m2crypto libgcrypt11 libgcrypt11-dev libnl-dev"
    install_packages "bc raspberrypi-kernel-headers"
}

function install_wireless_drivers() {
    local architecture="arm64"
    local driver_version="5.6.4.1"
    local install_directory="/tmp/rtl8812au"

    git clone "https://github.com/aircrack-ng/rtl8812au.git" "-b v${driver_version}" ${install_directory}

    if [ -d "${install_directory}" ]
    then
        pushd ${install_directory}

        if [ "${architecture}" == "arm" ] || [ "${architecture}" == "arm64" ]
        then
            sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' ${DRIVER_SOURCE_DIRECTORY}/Makefile
            sed -i "s/CONFIG_PLATFORM_${architecture^h}_RPI = n/CONFIG_PLATFORM_${architecture^h}_RPI = y/g" {DRIVER_SOURCE_DIRECTORY}/Makefile
        fi

        sh ${DRIVER_SOURCE_DIRECTORY}/dkms_install.sh
        popd
        rm -rf "${install_directory}"
    fi

    return 0
}

 install_depencies() 
 install_wireless_drivers()
