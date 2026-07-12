-- Keybindings configuration (ported from modules/binds.conf)

local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "dolphin"

-- Scratchpad — Super+` to toggle dropdown terminal
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd("kitty --class kitty-scratchpad"))
hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special("scratchpad"))

hl.window_rule({
    name = "scratchpad-rule",
    match = { class = "^kitty-scratchpad$" },
    workspace = "special:scratchpad",
    float = true,
    size = "900 550",
    center = true,
})

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M",
    hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/hypr-helper.sh ultralow"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.config/rofi/powermenu/type-2/powermenu.sh"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("~/.config/rofi/launchers/emoji/launcher.sh"))
hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybinds.py"))

-- ScreenShots
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("grimblast -n copy screen"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("python ~/.config/hypr/scripts/postimg-upload.py"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grimblast -n copysave area"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("~/.config/hypr/scripts/hypr-helper.sh ocr"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("~/.config/hypr/scripts/hypr-helper.sh qr"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/hypr-helper.sh record"))

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("rofi -show clipboard -theme ~/.config/rofi/launchers/type-1/style-5.rasi"))

hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/voice-dictate.sh"))
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("killall rofi || /home/m_frost/.config/rofi/launchers/type-1/launcher.sh"),
    { release = true })
hl.bind("ALT + TAB", hl.dsp.exec_cmd("~/.config/hypr/scripts/rofi-window.sh"))
hl.bind("ALT + ALT_L", hl.dsp.exec_cmd("~/.config/hypr/scripts/rofi-window.sh release"),
    { release = true, transparent = true })
hl.bind("ALT + ALT_R", hl.dsp.exec_cmd("~/.config/hypr/scripts/rofi-window.sh release"),
    { release = true, transparent = true })

hl.config({
    cursor = {
        zoom_factor = 1.0,
        zoom_rigid = false,
    }
})

hl.bind("SUPER + equal", hl.dsp.exec_cmd("~/.config/hypr/scripts/hypr-helper.sh zoom in"))
hl.bind("SUPER + minus", hl.dsp.exec_cmd("~/.config/hypr/scripts/hypr-helper.sh zoom out"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("~/.config/hypr/scripts/hypr-helper.sh zoom reset"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + ALT + [0-9]
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.5"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pamixer --default-source -t"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),
    { locked = true, repeating = true })



-- Media
-- Priority: Spotify first, then any non-browser player.
-- Browsers (LibreWolf, Firefox, Chromium, etc.) are structurally excluded so
-- a stray MPRIS-registering tab can never swallow media key commands.
-- Each bind also writes the action to /tmp/qs-media-action so the OSD:
--   a) shows the correct icon (play/pause vs next vs prev)
--   b) always fires even when the track title doesn't change (e.g. Spotify's
--      restart-track behaviour when pressing prev mid-song)
local _pc = "playerctl -p spotify_player,spotifyd,spotify"
    .. " --ignore-player=librewolf,firefox,firefox-esr,chromium,chromium-browser,google-chrome,brave,brave-browser"
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(_pc .. " play-pause; printf playpause > /tmp/qs-media-action"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(_pc .. " next;       printf next     > /tmp/qs-media-action"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(_pc .. " previous;   printf prev     > /tmp/qs-media-action"), { locked = true })

-- HyprExpo Plugin Binding
-- hl.bind(mainMod .. " + tab", function() hl.plugin.hyprexpo.expo("toggle") end)

-- Trigger screen lock immediately when laptop lid is closed
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true })
