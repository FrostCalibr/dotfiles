#!/bin/bash
#===============================================================
# MPRIS Pill — replaces built-in mpris module
# Outputs text + CSS class for background gradient fill
#===============================================================

# No player? Hide
playerctl status >/dev/null 2>&1 || exit 0

STATUS=$(playerctl status 2>/dev/null)
POS=$(playerctl position 2>/dev/null)
LEN=$(playerctl metadata mpris:length 2>/dev/null)
ARTIST=$(playerctl metadata xesam:artist 2>/dev/null)
TITLE=$(playerctl metadata xesam:title 2>/dev/null)
PLAYER=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)

# Fallbacks
[[ -z "$ARTIST" ]] && ARTIST="Unknown"
[[ -z "$TITLE" ]] && TITLE="Unknown"

# Icon selection
ICON="⏸"
[[ "$PLAYER" == "mpv" ]] && ICON="🎵"
[[ "$STATUS" == "Paused" ]] && ICON="▶"

# Format text
TEXT="$ICON $ARTIST - $TITLE"
[[ "${#TEXT}" -gt 35 ]] && TEXT="${TEXT:0:32}..."

# Calculate percentage
PCT=0
POS_SEC=${POS%.*}
LEN_SEC=$((LEN / 1000000))
[[ "$LEN_SEC" -gt 0 ]] && PCT=$((POS_SEC * 100 / LEN_SEC))
[[ "$PCT" -gt 100 ]] && PCT=100
[[ "$PCT" -lt 0 ]] && PCT=0

# Round to nearest 10
ROUNDED=$(((PCT + 5) / 10 * 10))
[[ "$ROUNDED" -gt 100 ]] && ROUNDED=100

# Build class
CLASS="pct-${ROUNDED}"
[[ "$STATUS" == "Paused" ]] && CLASS="${CLASS} paused"

# Output JSON
cat <<EOF
{"text": "$TEXT", "class": "$CLASS", "tooltip": "$STATUS — $POS_SEC / $LEN_SEC sec"}
EOF
