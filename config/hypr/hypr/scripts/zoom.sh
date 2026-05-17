#!/bin/bash

current=$(hyprctl getoption cursor:zoom_factor | awk '/float/{print $2}')

if [ -z "$current" ]; then
    current=1.0
fi

case "$1" in
    in)
        new=$(echo "$current + 0.5" | bc)
        ;;
    out)
        new=$(echo "$current - 0.5" | bc)
        new=$(echo "x=$new; if (x < 1.0) 1.0 else x" | bc)
        ;;
    reset)
        new=1.0
        ;;
    *)
        echo "Usage: zoom.sh [in|out|reset]"
        exit 1
        ;;
esac

new=$(printf "%.1f" "$new")
hyprctl keyword cursor:zoom_factor "$new"
