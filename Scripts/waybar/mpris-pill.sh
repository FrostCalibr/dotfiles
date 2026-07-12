#!/bin/bash
#===============================================================
# MPRIS Pill — replaces built-in mpris module
# Outputs text + CSS class for background gradient fill
#===============================================================

IGNORED=("firefox" "chromium" "brave" "librewolf")

# Find first non-ignored active player
PLAYER_INSTANCE=$(playerctl --list-all 2>/dev/null | while read -r p; do
    name=$(echo "$p" | cut -d'.' -f1 | tr '[:upper:]' '[:lower:]')
    for ignored in "${IGNORED[@]}"; do
        [[ "$name" == *"$ignored"* ]] && continue 2
    done
    echo "$p"
    break
done)

# No valid player? Hide
[[ -z "$PLAYER_INSTANCE" ]] && exit 0

P="--player=$PLAYER_INSTANCE"

STATUS=$(playerctl $P status 2>/dev/null)
POS=$(playerctl $P position 2>/dev/null)
LEN=$(playerctl $P metadata mpris:length 2>/dev/null)
ARTIST=$(playerctl $P metadata xesam:artist 2>/dev/null)
TITLE=$(playerctl $P metadata xesam:title 2>/dev/null)
PLAYER=$(playerctl $P metadata --format '{{playerName}}' 2>/dev/null)

# Fallbacks
[[ -z "$ARTIST" ]] && ARTIST="Unknown"
[[ -z "$TITLE" ]] && TITLE="Unknown"

# Icon selection
if [[ "$STATUS" == "Paused" ]]; then
    ICON="󰐊"
else
    case "${PLAYER,,}" in
        *spotify*) ICON="󰓇" ;;
        *vlc*)     ICON="󰕼" ;;
        *mpv*)     ICON="󰀥" ;;
        *)         ICON="󰎆" ;;
    esac
fi

# Format text
TEXT="$ICON $ARTIST - $TITLE"
[[ "${#TEXT}" -gt 35 ]] && TEXT="${TEXT:0:32}..."

# Format seconds into MM:SS or H:MM:SS
format_time() {
    local sec=$1
    [[ -z "$sec" || "$sec" -lt 0 ]] && sec=0
    local h=$((sec / 3600))
    local m=$(( (sec % 3600) / 60 ))
    local s=$((sec % 60))
    if [[ "$h" -gt 0 ]]; then
        printf "%d:%02d:%02d\n" "$h" "$m" "$s"
    else
        printf "%02d:%02d\n" "$m" "$s"
    fi
}

# Calculate percentage
PCT=0
POS_SEC=0
[[ -n "$POS" ]] && POS_SEC=${POS%.*}
LEN_SEC=0
[[ -n "$LEN" ]] && LEN_SEC=$((LEN / 1000000))

[[ "$LEN_SEC" -gt 0 ]] && PCT=$((POS_SEC * 100 / LEN_SEC))
[[ "$PCT" -gt 100 ]] && PCT=100
[[ "$PCT" -lt 0 ]] && PCT=0

# Round to nearest 10
ROUNDED=$(((PCT + 5) / 10 * 10))
[[ "$ROUNDED" -gt 100 ]] && ROUNDED=100

# Build class
CLASS="pct-${ROUNDED}"
[[ "$STATUS" == "Paused" ]] && CLASS="${CLASS} paused"

# Pretty player name
PLAYER_NAME="${PLAYER^}"

# Output JSON
cat <<EOF
{"text": "$TEXT", "class": "$CLASS", "tooltip": "$STATUS — $(format_time $POS_SEC) / $(format_time $LEN_SEC) ($PLAYER_NAME)"}
EOF
