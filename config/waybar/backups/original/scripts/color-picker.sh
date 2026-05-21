#!/bin/bash
COLOR=$(hyprpicker -a -f hex)
notify-send "Picked" "$COLOR" \
    --hint=string:bgcolor:$COLOR \
    --hint=string:fgcolor:#ffffff \
    --expire-time=4000
