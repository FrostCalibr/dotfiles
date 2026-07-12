#!/usr/bin/env bash

# ==============================================================================
# Frost Desktop Utility Helper
# Consolidates: zoom, ocr, qr-tool, screen-record, and ultralow energy settings.
# ==============================================================================

# ------------------------------------------------------------------------------
# OCR FUNCTION
# ------------------------------------------------------------------------------
run_ocr() {
    exec 2> /tmp/ocr_debug.log
    set -x
    IMG_PATH="/tmp/ocr_snapshot.png"
    TXT_PATH="/tmp/ocr_text"

    if ! grimblast save area "$IMG_PATH"; then
        exit 0
    fi

    if tesseract "$IMG_PATH" "$TXT_PATH" -l eng; then
        if [ -f "${TXT_PATH}.txt" ]; then
            text=$(tr -d '\f' < "${TXT_PATH}.txt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ -n "$text" ]; then
                echo -n "$text" | wl-copy
                notify-send -a "Screen OCR" -i edit-paste "Text Copied" "$text"
            else
                notify-send -a "Screen OCR" -i dialog-warning "OCR Failed" "No text recognized in selected area."
            fi
        else
            notify-send -a "Screen OCR" -i dialog-error "OCR Failed" "Could not read OCR output."
        fi
    else
        notify-send -a "Screen OCR" -i dialog-error "OCR Failed" "Tesseract failed to process the image."
    fi
    rm -f "$IMG_PATH" "${TXT_PATH}.txt"
}

# ------------------------------------------------------------------------------
# QR TOOL FUNCTION
# ------------------------------------------------------------------------------
run_qr() {
    ROFI_DIR="$HOME/.config/rofi/launchers/type-1"
    ROFI_THEME="style-5"
    options="󰐳 Scan QR Code from Screen\n󱌣 Generate QR Code from Clipboard"
    chosen=$(echo -e "$options" | rofi -dmenu -p "QR Tool" -theme "${ROFI_DIR}/${ROFI_THEME}.rasi")

    case "$chosen" in
        *Scan*)
            IMG_PATH="/tmp/qr_snapshot.png"
            TXT_PATH="/tmp/qr_text.txt"
            if ! grimblast save area "$IMG_PATH"; then
                exit 0
            fi
            if zbarimg --raw -q "$IMG_PATH" > "$TXT_PATH" 2>/dev/null; then
                content=$(cat "$TXT_PATH" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                if [ -n "$content" ]; then
                    echo -n "$content" | wl-copy
                    if [[ "$content" =~ ^https?:// ]]; then
                        xdg-open "$content"
                        notify-send -a "QR Scanner" -i xdg-desktop-portal "URL Opened & Copied" "$content"
                    else
                        notify-send -a "QR Scanner" -i edit-paste "Content Copied" "$content"
                    fi
                else
                    notify-send -a "QR Scanner" -i dialog-warning "Scan Failed" "QR code was empty."
                fi
            else
                notify-send -a "QR Scanner" -i dialog-warning "Scan Failed" "No QR code detected in selected area."
            fi
            rm -f "$IMG_PATH" "$TXT_PATH"
            ;;
        *Generate*)
            content=$(wl-paste)
            if [ -z "$content" ]; then
                notify-send -a "QR Generator" -i dialog-warning "Clipboard Empty" "No text found in clipboard."
                exit 0
            fi
            QR_PATH="/tmp/qr_code.png"
            if qrencode -o "$QR_PATH" "$content"; then
                yad --picture \
                    --filename="$QR_PATH" \
                    --title="QR Code Share" \
                    --width=320 \
                    --height=320 \
                    --size=fit \
                    --button="Close:0" \
                    --undecorated \
                    --on-top \
                    --center
            else
                notify-send -a "QR Generator" -i dialog-error "Generation Failed" "Could not generate QR code."
            fi
            rm -f "$QR_PATH"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# SCREEN RECORD FUNCTION
# ------------------------------------------------------------------------------
run_record() {
    SAVE_DIR="$HOME/Videos/Recordings"
    mkdir -p "$SAVE_DIR"
    STATUS_FILE="/tmp/wf-recorder-active"
    PID_FILE="/tmp/wf-recorder.pid"
    PATH_FILE="/tmp/wf-recorder-path"

    if pgrep -x "wf-recorder" > /dev/null; then
        PID=$(cat "$PID_FILE" 2>/dev/null || pgrep -x "wf-recorder")
        FILE_PATH=$(cat "$PATH_FILE" 2>/dev/null)
        kill -SIGINT "$PID" 2>/dev/null
        while pgrep -x "wf-recorder" > /dev/null; do
            sleep 0.5
        done
        rm -f "$STATUS_FILE" "$PID_FILE" "$PATH_FILE"
        if [ -f "$FILE_PATH" ]; then
            ACTION=$(notify-send \
                -a "Screen Recorder" \
                -i "video-x-generic" \
                --action="play=󰐊 Play Video" \
                --action="open=󰉋 Open Folder" \
                --action="delete=󰩹 Delete File" \
                "Recording Saved" \
                "File: $(basename "$FILE_PATH")\nLocation: $SAVE_DIR")
            case "$ACTION" in
                "play") xdg-open "$FILE_PATH" & ;;
                "open") nemo "$SAVE_DIR" & ;;
                "delete")
                    rm -f "$FILE_PATH"
                    notify-send -a "Screen Recorder" -i "edit-delete" "Recording Deleted" "The video file has been removed."
                    ;;
            esac
        else
            notify-send -a "Screen Recorder" -i "dialog-error" "Recording Failed" "Could not find the saved recording."
        fi
        exit 0
    fi

    OPTIONS="󰍹  Record Screen (Silent)\n󰍬  Record Screen + Audio\n󰆚  Record Area (Silent)\n󰕾  Record Area + Audio"
    SELECTED=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Screen Recorder" -theme ~/.config/rofi/launchers/type-1/style-5.rasi)
    if [ -z "$SELECTED" ]; then
        exit 0
    fi

    FILENAME="Recording_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
    OUTPUT_FILE="$SAVE_DIR/$FILENAME"
    ARGS=()
    case "$SELECTED" in
        *"Area"*)
            GEOM=$(slurp)
            if [ -z "$GEOM" ]; then
                notify-send -a "Screen Recorder" -i "dialog-warning" "Recording Cancelled" "No area was selected."
                exit 0
            fi
            ARGS+=(-g "$GEOM")
            ;;
    esac
    case "$SELECTED" in
        *"+"*|*"Audio"*) ARGS+=(-a) ;;
    esac

    echo "$OUTPUT_FILE" > "$PATH_FILE"
    wf-recorder "${ARGS[@]}" -f "$OUTPUT_FILE" > /dev/null 2>&1 &
    REC_PID=$!
    echo "$REC_PID" > "$PID_FILE"
    touch "$STATUS_FILE"
    notify-send -a "Screen Recorder" -i "media-record" "Recording Started" "Press SUPER+R to stop recording.\nSaving to: $FILENAME"
}

# ------------------------------------------------------------------------------
# ZOOM FUNCTION
# ------------------------------------------------------------------------------
run_zoom() {
    current=$(hyprctl getoption cursor:zoom_factor | awk '/float/{print $2}')
    if [ -z "$current" ]; then
        current=1.0
    fi
    case "$1" in
        in)    new=$(echo "$current + 0.5" | bc) ;;
        out)   new=$(echo "$current - 0.5" | bc)
               new=$(echo "x=$new; if (x < 1.0) 1.0 else x" | bc) ;;
        reset) new=1.0 ;;
        *)     echo "Usage: zoom [in|out|reset]" && exit 1 ;;
    esac
    new=$(printf "%.1f" "$new")
    hyprctl keyword cursor:zoom_factor "$new"
}

# ------------------------------------------------------------------------------
# ULTRA LOW POWER FUNCTION (escalates to root via pkexec)
# ------------------------------------------------------------------------------
run_ultralow() {
    STATE_FILE="/tmp/.ultralow_active"
    WIFI_INTERFACE="wlan0"
    HYPR_USER=$(who | awk '{print $1}' | head -1)
    HYPR_INSTANCE=$(ls /run/user/$(id -u $HYPR_USER)/hypr/ | head -1)

    if [ $EUID -ne 0 ]; then
        echo "Please run as Root! Trying to Elevate..."
        pkexec --user root "$0" "$@"
        exit
    fi

    hyprctl-cmd(){
        sudo -u $HYPR_USER HYPRLAND_INSTANCE_SIGNATURE=$HYPR_INSTANCE hyprctl $@
    }

    notify(){
        sudo -u $HYPR_USER \
        env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $HYPR_USER)/bus \
        notify-send "$@"
    }

    disable_low_power(){
        rm -f "$STATE_FILE"
        cpupower frequency-set -g performance
        brightnessctl set 10%
        iw dev $WIFI_INTERFACE set power_save off
        rfkill unblock bluetooth
        for f in /sys/bus/usb/devices/*/power/control; do
            echo 'on' > $f 2>/dev/null
        done
        hyprctl-cmd keyword animations:enabled true
        hyprctl-cmd keyword decoration:blur:enabled true
        notify "󰁹 Normal Mode" "Power restored"
    }

    enable_low_power(){
        touch "$STATE_FILE"
        cpupower frequency-set -g powersave
        brightnessctl set 1
        iw dev $WIFI_INTERFACE set power_save on
        rfkill block bluetooth
        powertop --auto-tune
        for f in /sys/bus/usb/devices/*/power/control; do
            echo 'auto' > $f 2>/dev/null
        done
        hyprctl-cmd keyword animations:enabled false
        hyprctl-cmd keyword decoration:blur:enabled false
        notify "󰂏 Ultra Low Power" "Mode enabled"
    }

    if [ -f "$STATE_FILE" ]; then
        disable_low_power
    else
        enable_low_power
    fi
}

# ------------------------------------------------------------------------------
# CAFFEINE MODE FUNCTION
# ------------------------------------------------------------------------------
run_caffeine() {
    STATE_FILE="/tmp/.caffeine_active"
    if [ -f "$STATE_FILE" ]; then
        # Disable Caffeine
        rm -f "$STATE_FILE"
        if ! pgrep -x "hypridle" > /dev/null; then
            setsid hypridle >/dev/null 2>&1 &
        fi
        notify-send -a "Caffeine" -i coffee "Caffeine Disabled" "Screen sleep and locking are now enabled."
    else
        # Enable Caffeine
        touch "$STATE_FILE"
        pkill hypridle
        notify-send -a "Caffeine" -i coffee "Caffeine Enabled" "Screen sleep and locking are now disabled."
    fi
    # Signal Waybar to refresh custom/caffeine
    pkill -RTMIN+10 waybar 2>/dev/null || true
}

caffeine_status() {
    STATE_FILE="/tmp/.caffeine_active"
    if [ -f "$STATE_FILE" ] || ! pgrep -x "hypridle" > /dev/null; then
        echo '{"text": "󰛊", "class": "active", "tooltip": "Caffeine Mode: Enabled\n(Screen sleep & lock disabled)"}'
    else
        echo '{"text": "󰛉", "class": "inactive", "tooltip": "Caffeine Mode: Disabled\n(Screen sleep & lock enabled)"}'
    fi
}

# ------------------------------------------------------------------------------
# MAIN COMMAND DISPATCHER
# ------------------------------------------------------------------------------
case "$1" in
    ocr)             run_ocr ;;
    qr)              run_qr ;;
    record)          run_record ;;
    zoom)            run_zoom "${2:-}" ;;
    ultralow)        run_ultralow "$@" ;;
    caffeine)        run_caffeine ;;
    caffeine-status) caffeine_status ;;
    *)
        echo "Usage: hypr-helper.sh [ocr|qr|record|zoom|ultralow|caffeine|caffeine-status]"
        exit 1
        ;;
esac
