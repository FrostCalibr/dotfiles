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
	"gtk-3.0:$CONFIG/gtk-3.0:config/gtk-3.0"
	"gtk-4.0:$CONFIG/gtk-4.0:config/gtk-4.0"
    "spicetify:$CONFIG/spicetify:config/spicetify"
    "spotify-player:$CONFIG/spotify-player:config/spotify-player"
    "superfile:$CONFIG/superfile:config/superfile"
    "starship:$CONFIG/starship.toml:config/starship.toml"
	"pacseek:$CONFIG/pacseek:config/pacseek"
	"zshrc:$HOME/.zshrc:./.zshrc"
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

    # Create destination parent directory if needed
    mkdir -p "$(dirname "$dest")"

    if [ -d "$src" ]; then
        # Ensure destination directory exists and is clean
        [ -d "$dest" ] && rm -rf "$dest"
        mkdir -p "$dest"
        # Sync directory using rsync with exclusions
        rsync -a --delete \
            --exclude='.git/' \
            --exclude='node_modules/' \
            --exclude='venv/' \
            --exclude='.venv/' \
            --exclude='env/' \
            --exclude='.env' \
            --exclude='*.env' \
            --exclude='__pycache__/' \
            --exclude='*.pyc' \
            --exclude='*.pyo' \
            --exclude='*.pyd' \
            --exclude='.cache/' \
            --exclude='cache/' \
            --exclude='*token*' \
            --exclude='*secret*' \
            --exclude='*password*' \
            --exclude='*credentials*' \
            "$src/" "$dest/"
    else
        # For single files, just copy
        [ -e "$dest" ] && rm -f "$dest"
        cp "$src" "$dest"
    fi
    echo -e "  ${GREEN}󰗠${RESET}  $label"
}

# ── Phase 1: Sync ─────────────────────────────────────────────────────────────

echo -e "\n${BOLD} Syncing files${RESET}\n"

for entry in "${TRACKED[@]}"; do
    IFS=':' read -r label src dest_rel <<< "$entry"
    sync_item "$src" "$DOTFILES/$dest_rel" "$label"
done

# ── Phase 1.5: Secret Scanner ─────────────────────────────────────────────────

# Run inline Python scanner on the synced files to detect potential secrets
if ! DOTFILES="$DOTFILES" python3 - << 'EOF'
import os, re, sys

# Color formatting
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
RESET = '\033[0m'
BOLD = '\033[1m'

PATTERNS = [
    (re.compile(r'gsk_[a-zA-Z0-9]{48}'), "Groq API Key"),
    (re.compile(r'ghp_[a-zA-Z0-9]{36}'), "GitHub Classic Token"),
    (re.compile(r'github_pat_[a-zA-Z0-9_]{82}'), "GitHub Fine-grained Token"),
    (re.compile(r'xox[bapr]-[0-9]{12}-[a-zA-Z0-9]{24}'), "Slack Token"),
    (re.compile(r'(?i)(api[-_]?key|api[-_]?token|secret|password|passwd|credential|private[-_]?key)\s*=\s*[\'"]([a-zA-Z0-9_\-\.\~]{12,})[\'"]'), "Potential Secret Assignment")
]

PLACEHOLDERS = {
    "your_api_key", "your_token", "your_secret", "placeholder", "todo", "enter_", "insert_", "config", "true", "false", "null"
}

def is_placeholder(val):
    val_lower = val.lower()
    return any(p in val_lower for p in PLACEHOLDERS)

def scan_file(filepath):
    findings = []
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line_idx, line in enumerate(f, 1):
                line = line.strip()
                if not line or line.startswith('#') or line.startswith('//'):
                    continue
                for pattern, desc in PATTERNS:
                    matches = pattern.finditer(line)
                    for match in matches:
                        if desc == "Potential Secret Assignment":
                            var_name = match.group(1)
                            val = match.group(2)
                            if is_placeholder(val):
                                continue
                            redacted = f"{var_name} = '{val[:3]}...{val[-3:]}'"
                        else:
                            val = match.group(0)
                            if is_placeholder(val):
                                continue
                            redacted = f"'{val[:8]}...{val[-4:]}'"
                        findings.append((line_idx, desc, redacted))
    except Exception:
        pass
    return findings

def main():
    dotfiles_dir = os.environ.get("DOTFILES", os.path.expanduser("~/dotfiles"))
    has_findings = False
    
    print(f"\n{BOLD}🔍 Scanning dotfiles for secrets...{RESET}")
    for root, dirs, files in os.walk(dotfiles_dir):
        if '.git' in dirs:
            dirs.remove('.git')
        for file in files:
            filepath = os.path.join(root, file)
            if os.path.islink(filepath):
                continue
            findings = scan_file(filepath)
            if findings:
                has_findings = True
                rel_path = os.path.relpath(filepath, dotfiles_dir)
                print(f"  {RED}✗{RESET} Potential secret(s) found in {BOLD}{rel_path}{RESET}:")
                for line_num, desc, redacted in findings:
                    print(f"    {YELLOW}Line {line_num}:{RESET} [{desc}] -> {redacted}")
                    
    if has_findings:
        sys.exit(1)
    print(f"  {GREEN}✓{RESET} No secrets detected.")
    sys.exit(0)

if __name__ == "__main__":
    main()
EOF
then
    echo ""
    read -rp "$(echo -e "${BOLD}${RED}⚠️ Secrets detected! Do you want to proceed committing anyway? (y/N): ${RESET}")" proceed
    if [[ ! "${proceed:-n}" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted to prevent secret leakage.${RESET}"
        exit 1
    fi
fi

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
