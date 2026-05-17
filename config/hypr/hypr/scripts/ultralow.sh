#!/bin/bash


STATE_FILE="/tmp/.ultralow_active"
WIFI_INTERFACE="wlan0"
HYPR_USER=$(who | awk '{print $1}' | head -1)
HYPR_INSTANCE=$(ls /run/user/$(id -u $HYPR_USER)/hypr/ | head -1)


#check if runned as root
if [ $EUID -ne 0 ]; then
    echo -e "Please run as Root! \n Trying to Elevate..."
    
    pkexec --user root "$0" "$@"
    exit
fi

#Switching user(root) to currently running user for certain instances 
hyprctl-cmd(){
    sudo -u $HYPR_USER HYPRLAND_INSTANCE_SIGNATURE=$HYPR_INSTANCE hyprctl $@
}

notify(){
    sudo -u $HYPR_USER \
    env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $HYPR_USER)/bus \
    notify-send "$@"
}

#Main Funtions
disable_low_power(){
    rm "$STATE_FILE"
    
    cpupower frequency-set -g performance
    brightnessctl set 10%
    iw dev $WIFI_INTERFACE set power_save off
    rfkill unblock bluetooth
    
    #hyprland
    hyprctl-cmd keyword animations:enabled true
    hyprctl-cmd keyword decoration:blur:enabled true

    notify "󰁹 Normal Mode" "Power restored"
    echo "Low Power OFF"
}

enable_low_power(){
    touch "$STATE_FILE"
    
    cpupower frequency-set -g powersave
    brightnessctl set 1 #sets 
    iw dev $WIFI_INTERFACE set power_save on
    rfkill block bluetooth
    powertop --auto-tune

    for f in /sys/bus/usb/devices/*/power/control; do
        echo 'on' > $f
    done

    #hyprland
    hyprctl-cmd keyword animations:enabled false
    hyprctl-cmd keyword decoration:blur:enabled false

    notify "󰂏 Ultra Low Power" "Mode enabled"
    echo "Low Power ON"
}


#Enable/Disable
if [  -f "$STATE_FILE" ]; then
    echo "Currently in Low Power mode. Disabling.."
    disable_low_power
else
    echo "Enabling Low power mode..."
    enable_low_power
fi


