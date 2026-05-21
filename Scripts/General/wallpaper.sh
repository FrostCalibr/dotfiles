#!/usr/bin/env bash
# wallpaper.sh — set wallpaper + regenerate matugen theme
# Usage:
#   wallpaper.sh <path/to/image>       set a specific wallpaper
#   wallpaper.sh --random <directory>  pick a random one from a folder
#   wallpaper.sh --pick                open a file picker (requires yad or zenity)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/current_wallpaper"
# Reload kitty after matugen runs (sends USR1 signal to all kitty instances)
RELOAD_KITTY=true

# ── Matugen tuning ────────────────────────────────────────────────────────────
# Scheme type: scheme-vibrant | scheme-expressive | scheme-rainbow |
#              scheme-fruit-salad | scheme-fidelity | scheme-tonal-spot (default)
MATUGEN_SCHEME="scheme-expressive"
# Contrast: -1 (min) to 1 (max). 0 = spec default
MATUGEN_CONTRAST="0.6"
# Lightness boost for dark mode: 0 = spec default, higher = brighter (try 0.2–0.5)
MATUGEN_LIGHTNESS="0.2"
# Source color preference: saturation | lightness | darkness | value | less-saturation
MATUGEN_PREFER="value"
# Source color index: 0 = most dominant, 1–4 = less dominant (leave empty to prompt)
MATUGEN_COLOR_INDEX=""
# ─────────────────────────────────────────────────────────────────────────────

die()  { echo "error: $*" >&2; exit 1; }
info() { echo "  $*"; }

# ── Dependency check ──────────────────────────────────────────────────────────
for cmd in awww matugen; do
  command -v "$cmd" &>/dev/null || die "'$cmd' not found in PATH"
done

# ── Argument parsing ──────────────────────────────────────────────────────────
pick_random() {
  local dir="${1:-$WALLPAPER_DIR}"
  [[ -d "$dir" ]] || die "directory not found: $dir"
  find "$dir" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o \
    -iname "*.png" -o -iname "*.webp" \
  \) | shuf -n1
}

pick_file() {
  if command -v yad &>/dev/null; then
    yad --file --title="Pick a wallpaper" \
        --file-filter="Images|*.jpg *.jpeg *.png *.webp" \
        --filename="$WALLPAPER_DIR/"
  elif command -v zenity &>/dev/null; then
    zenity --file-selection --title="Pick a wallpaper" \
           --file-filter="*.jpg *.jpeg *.png *.webp" \
           --filename="$WALLPAPER_DIR/"
  else
    die "--pick requires yad or zenity"
  fi
}

case "${1:-}" in
  --random)
    WALLPAPER="$(pick_random "${2:-}")"
    ;;
  --pick)
    WALLPAPER="$(pick_file)"
    [[ -n "$WALLPAPER" ]] || die "no file selected"
    ;;
  -h|--help)
    sed -n '2,5p' "$0" | sed 's/^# //'
    exit 0
    ;;
  "")
    # No args — re-apply the last used wallpaper (useful after reboot)
    [[ -f "$CACHE_FILE" ]] || die "no cached wallpaper and no argument given"
    WALLPAPER="$(cat "$CACHE_FILE")"
    info "re-applying cached wallpaper"
    ;;
  *)
    WALLPAPER="$1"
    ;;
esac

# ── Validate ──────────────────────────────────────────────────────────────────
[[ -f "$WALLPAPER" ]] || die "file not found: $WALLPAPER"

echo "🖼  $(basename "$WALLPAPER")"

# ── Set wallpaper ─────────────────────────────────────────────────────────────
info "setting wallpaper with awww..."
awww img "$WALLPAPER"

# ── Build matugen args ────────────────────────────────────────────────────────
MATUGEN_ARGS=(
  -t "$MATUGEN_SCHEME"
  --contrast "$MATUGEN_CONTRAST"
  --lightness-dark "$MATUGEN_LIGHTNESS"
  --prefer "$MATUGEN_PREFER"
)
[[ -n "$MATUGEN_COLOR_INDEX" ]] && MATUGEN_ARGS+=(--source-color-index "$MATUGEN_COLOR_INDEX")

# ── Generate theme ────────────────────────────────────────────────────────────
info "generating matugen theme (${MATUGEN_SCHEME}, contrast=${MATUGEN_CONTRAST}, lightness=${MATUGEN_LIGHTNESS})..."
matugen "${MATUGEN_ARGS[@]}" image "$WALLPAPER"

# ── Reload kitty ─────────────────────────────────────────────────────────────
if [[ "$RELOAD_KITTY" == true ]]; then
  if pgrep -x kitty &>/dev/null; then
    info "reloading kitty..."
    pkill -USR1 kitty 2>/dev/null || true
  fi
fi

# ── Cache ─────────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$CACHE_FILE")"
echo "$WALLPAPER" > "$CACHE_FILE"

echo "✓ done"
