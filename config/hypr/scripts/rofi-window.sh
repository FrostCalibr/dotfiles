#!/usr/bin/env bash

case "$1" in
    release)
        # If Rofi is running, press Enter/Return to select the highlighted window
        if pgrep -x rofi >/dev/null; then
            wtype -k Return
        fi
        ;;
    *)
        # Default/cycle: if Rofi is already running, send "Tab" to cycle
        if pgrep -x rofi >/dev/null; then
            wtype -k Tab
        else
            # Otherwise launch Rofi in window switcher mode
            rofi -show window -theme ~/.config/rofi/launchers/type-1/style-5.rasi
        fi
        ;;
esac
