-- ~/.config/hypr/modules/envvars.lua
-- Environment variables for Hyprland session (ported from modules/envvars.conf)

-- Cursor 
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")

-- Wayland backends 
hl.env("GDK_BACKEND", "wayland,x11,*")          -- GTK: prefer Wayland, fallback X11
hl.env("SDL_VIDEODRIVER", "wayland")            -- SDL2 games/apps run natively on Wayland
hl.env("CLUTTER_BACKEND", "wayland")

-- Qt 
hl.env("QT_QPA_PLATFORM", "wayland;xcb")        -- Qt: prefer Wayland, fallback XCB
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")     -- Qt DPI auto-scaling
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")  -- No client-side decorations on Qt apps
hl.env("QT_QPA_PLATFORMTHEME", "kde")      -- Use KDE for Qt platform theme (reads kdeglobals)
hl.env("QT_STYLE_OVERRIDE", "kvantum")    -- Force Kvantum style for Qt applications

-- Firefox / Mozilla 
hl.env("MOZ_ENABLE_WAYLAND", "1")              -- Native Wayland rendering in Firefox

-- Electron apps (VSCode, Discord, Obsidian …) 
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto") -- Electron 28+: auto-detect Wayland/X11

-- Java / Swing 
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")    -- Fixes blank/black Java GUI windows

-- XDG 
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SCREENSHOTS_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")

-- Misc 
-- OZONE_PLATFORM intentionally omitted — GDK_BACKEND handles Wayland preference;
-- forcing OZONE can break some Electron/Chromium apps on mixed setups

-- Proton path
local PROTONPATH = "/home/m_frost/.local/share/proton-ge/GE-Proton11-1"
