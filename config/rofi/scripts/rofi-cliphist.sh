#!/usr/bin/env bash

# If no arguments, list cliphist history
if [ -z "$1" ]; then
    cliphist list
else
    # User selected an item, decode and copy back to clipboard
    printf "%s" "$1" | cliphist decode | wl-copy
fi
