#!/bin/bash
# Dotfile Syncer
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m';     DIM='\033[2m'; RESET='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
DOTFILES="$HOME/dotfiles"
CONFIG="$HOME/.config"

# Format: "label:source:dest_relative_to_dotfiles"
TRACKED=(
    "btop:$CONFIG/btop:config/btop"
    "cava:$CONFIG/cava:config/cava"
    "greenclip:$CONFIG/greenclip.toml:config/greenclip.toml"
    "hypr:$CONFIG/hypr:config/hypr"
    "kitty:$CONFIG/kitty:config/kitty"
    "matugen:$CONFIG/matugen:config/matugen"
    "micro:$CONFIG/micro:config/micro"
    "nvim:$CONFIG/nvim:config/nvim"
    "rofi:$CONFIG/rofi:config/rofi"
    "spicetify:$CONFIG/spicetify:config/spicetify"
    "superfile:$CONFIG/superfile:config/superfile"
	"pacseek:$CONFIG/pacseek:config/pacseek"
	"swaync:$CONFIG/swaync:config/swaync"
    "swayosd:$CONFIG/swayosd:config/swayosd"
    "waybar:$CONFIG/waybar:config/waybar"
    "Scripts:$HOME/Scripts:Scripts"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

has_changes() {
    [ -n "$(git -C "$DOTFILES" status --porcelain -- "$1")" ]
}

sync_item() {
    local src="$1" dest="$2" label="$3"

    if [ ! -e "$src" ]; then
        echo -e "  ${RED}󰅙${RESET}  $label ${DIM}(not found, skipping)${RESET}"
        return
    fi

    [ -d "$dest" ] && rm -rf "$dest"
    [ -e "$dest" ] && rm -f "$dest"

    cp -r "$src" "$dest"
    echo -e "  ${GREEN}󰗠${RESET}  $label"
}

# ── Phase 1: Sync ─────────────────────────────────────────────────────────────

echo -e "\n${BOLD} Syncing files${RESET}\n"

for entry in "${TRACKED[@]}"; do
    IFS=':' read -r label src dest_rel <<< "$entry"
    sync_item "$src" "$DOTFILES/$dest_rel" "$label"
done

# ── Phase 2: Detect changes ───────────────────────────────────────────────────

declare -a CHANGED_ENTRIES=()
for entry in "${TRACKED[@]}"; do
    IFS=':' read -r label src dest_rel <<< "$entry"
    has_changes "$dest_rel" && CHANGED_ENTRIES+=("$entry")
done

if [ ${#CHANGED_ENTRIES[@]} -eq 0 ]; then
    echo -e "\n${DIM}No changes to commit.${RESET}\n"
    exit 0
fi

# ── Phase 3: Show summary, pick mode ─────────────────────────────────────────

echo -e "\n${BOLD}󰷈  Changed items:${RESET}"
for entry in "${CHANGED_ENTRIES[@]}"; do
    IFS=':' read -r label src dest_rel <<< "$entry"
    echo -e "  ${YELLOW}•${RESET} $label"
done

echo ""
echo -e "${DIM}  a  = commit all with one message${RESET}"
echo -e "${DIM}  r  = review and commit each one individually${RESET}"
read -rp "$(echo -e "${BOLD}  Choice [a/r]: ${RESET}")" mode

case "$mode" in
    a|A)
        # ── Commit all ────────────────────────────────────────────────────────
        read -rp "  Commit message: " msg
        [ -z "$msg" ] && echo "No message entered, aborting." && exit 1
        git -C "$DOTFILES" add .
        git -C "$DOTFILES" commit -m "$msg"
        echo -e "\n  ${GREEN}All committed.${RESET}"
        ;;

    *)
        # ── Per-item review ───────────────────────────────────────────────────
        committed=0; skipped=0

        for entry in "${CHANGED_ENTRIES[@]}"; do
            IFS=':' read -r label src dest_rel <<< "$entry"

            echo -e "\n${BOLD}${CYAN}── $label${RESET} ${DIM}($dest_rel)${RESET}"
            git -C "$DOTFILES" status --short -- "$dest_rel"

            echo -e "${DIM}  Enter = auto message  │  s = skip  │  or type a custom message${RESET}"
            read -rp "  > " choice

            case "$choice" in
                s|S)
                    echo -e "  ${YELLOW}Skipped${RESET}"
                    skipped=$((skipped + 1))
                    ;;
                "")
                    git -C "$DOTFILES" add -- "$dest_rel"
                    git -C "$DOTFILES" commit -m "Update $label"
                    echo -e "  ${GREEN}Committed:${RESET} Update $label"
                    committed=$((committed + 1))
                    ;;
                *)
                    git -C "$DOTFILES" add -- "$dest_rel"
                    git -C "$DOTFILES" commit -m "$choice"
                    echo -e "  ${GREEN}Committed:${RESET} $choice"
                    committed=$((committed + 1))
                    ;;
            esac
        done

        echo -e "\n${BOLD}Summary:${RESET} ${GREEN}$committed committed${RESET} · ${YELLOW}$skipped skipped${RESET}"
        ;;
esac

# ── Phase 4: Push ─────────────────────────────────────────────────────────────

BRANCH=$(git -C "$DOTFILES" symbolic-ref --short HEAD 2>/dev/null || echo "main")

if git -C "$DOTFILES" log "origin/$BRANCH..HEAD" --oneline 2>/dev/null | grep -q .; then
    echo ""
    read -rp "$(echo -e "${BOLD}Push to origin/$BRANCH? [Y/n]: ${RESET}")" push
    if [[ "${push:-y}" =~ ^[Nn]$ ]]; then
        echo -e "${DIM}Push skipped.${RESET}"
    else
        git -C "$DOTFILES" push
        echo -e "\n${GREEN}Done!${RESET}"
    fi
else
    echo -e "\n${DIM}Nothing to push.${RESET}"
fi
