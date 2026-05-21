#!/bin/bash
# Dotfile Syncer
set -euo pipefail

DOTFILES="$HOME/dotfiles"
CONFIG="$HOME/.config"

CONFIG_TRACKED=(
    btop cava greenclip.toml hypr kitty
    matugen micro nvim rofi spicetify
    superfile swayosd waybar
)

HOME_TRACKED=(
    "Scripts:Scripts"
)

sync_item() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ ! -e "$src" ]; then
        echo "󰅙 $label not found"
        return
    fi

    if [ -d "$dest" ]; then
        rm -rf "$dest"
    elif [ -e "$dest" ]; then
        rm -f "$dest"
    fi

    cp -r "$src" "$dest"
    echo "󰗠  $label"
}

commit_item() {
    local dest_rel="$1"   # path relative to dotfiles root
    local label="$2"

    # Check if this item has any changes
    if git -C "$DOTFILES" diff --quiet -- "$dest_rel" && \
       git -C "$DOTFILES" diff --cached --quiet -- "$dest_rel"; then
        return  # no changes, skip silently
    fi

    echo ""
    echo "󰷈 Changes in $label:"
    git -C "$DOTFILES" diff --stat -- "$dest_rel"

    read -rp "  Commit '$label'? [y/N/msg] " choice
    case "$choice" in
        y|Y)
            msg="Update $label"
            ;;
        n|N|"")
            echo "  Skipped."
            return
            ;;
        *)
            # Anything else is treated as the commit message itself
            msg="$choice"
            ;;
    esac

    git -C "$DOTFILES" add -- "$dest_rel"
    git -C "$DOTFILES" commit -m "$msg"
    echo "  󰗠 Committed: $msg"
}

# ── Sync ─────────────────────────────────────────────────────────────────────

echo " Syncing files"

for item in "${CONFIG_TRACKED[@]}"; do
    sync_item "$CONFIG/$item" "$DOTFILES/config/$item" "$item"
done

for entry in "${HOME_TRACKED[@]}"; do
    src_rel="${entry%%:*}"
    dest_rel="${entry##*:}"
    sync_item "$HOME/$src_rel" "$DOTFILES/$dest_rel" "$src_rel"
done

# ── Commit ────────────────────────────────────────────────────────────────────

if git -C "$DOTFILES" diff --quiet && git -C "$DOTFILES" diff --cached --quiet; then
    echo ""
    echo "No changes to commit."
    exit 0
fi

echo ""
echo "Reviewing changes per item..."

for item in "${CONFIG_TRACKED[@]}"; do
    commit_item "config/$item" "$item"
done

for entry in "${HOME_TRACKED[@]}"; do
    dest_rel="${entry##*:}"
    commit_item "$dest_rel" "$dest_rel"
done

# ── Push ──────────────────────────────────────────────────────────────────────

if git -C "$DOTFILES" log origin/main..HEAD --oneline | grep -q .; then
    echo ""
    read -rp "Push all commits? [Y/n] " push
    if [[ "$push" =~ ^[Nn]$ ]]; then
        echo "Skipped push."
    else
        git -C "$DOTFILES" push
        echo "Done!"
    fi
else
    echo ""
    echo "Nothing to push."
fi
