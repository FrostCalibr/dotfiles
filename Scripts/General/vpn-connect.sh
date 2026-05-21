#!/bin/bash

STATUS=$(protonvpn status)

STATE=$(echo "$STATUS" | grep "^Status:" | awk '{print $2}')

case "$1" in 
    (--toggle)
        if [ "$STATE" = "Connected" ]; then
            protonvpn disconnect

    
        elif [ "$STATE" = "Disconnected" ]; then
            protonvpn connect
        fi
        ;;

    (--status)
        TEXT="󰒃 VPN"
        SERVER=$(echo "$STATUS" | grep "^Server:" | cut -d' ' -f2-)
        


        if [ "$STATE" = "Connected" ]; then
            echo "{\"text\":\"$TEXT\", \"tooltip\":\"$SERVER\", \"class\":\"connected\"}"

    
        elif [ "$STATE" = "Disconnected" ]; then
            echo "{\"text\":\"$TEXT\", \"tooltip\":\"Disconnected\", \"class\":\"disconnected\"}"
        fi
        ;;
    (*)
        echo "Usage: vpn.sh [--toggle|--status]"
        ;;
esac
        


