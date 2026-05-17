#!/bin/bash

DOTFILES="$HOME/dotfiles"
CONFIG="$HOME/.config"

TRACKED=(
    btop cava greenclip.toml hypr kitty
    matugen micro nvim rofi spicetify
    superfile swayosd waybar
)

echo " Syncing files"

for item in "${TRACKED[@]}"; do
    src="$CONFIG/$item"
    dest="$DOTFILES/config/$item"

    if [ -e "$src" ]; then
        cp -r "$src" "$dest"
        echo "󰗠  $item"
    else
        echo "󰅙 $item not found"
    fi
done

echo ""
echo "󰷈 Changes:"
git -C "$DOTFILES" status --short

echo ""
read -p "Commit message: " msg

if [ -z "$msg" ]; then
    echo "No message entered, aborting."
    exit 1
fi


git -C "$DOTFILES" add .
git -C "$DOTFILES" commit -m "$msg"
git -C "$DOTFILES" push 

echo "Done!"