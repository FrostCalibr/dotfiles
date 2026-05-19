#!/usr/bin/env bash
## Emoji picker using rofimoji
## Follows adi1090x rofi config pattern
## Place at: ~/.config/rofi/launchers/emoji/launcher.sh

dir="$HOME/.config/rofi/launchers/emoji"

rofimoji \
    --action copy \
    --hidden-descriptions \
    --selector-args=" \
        -theme ${dir}/grid.rasi \
        -kb-row-left Left \
        -kb-row-right Right \
        -kb-move-char-back ctrl+b \
        -kb-move-char-forward ctrl+f"
