-- Window and Layer rules (ported from modules/windowrules.conf)

-- Ignore maximize requests from all apps
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- Hyprland-run float position
hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

-- Float common utility apps
hl.window_rule({
    name = "float-utilities",
    match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor|Calculator)$" },
    float = true,
    center = true,
})

-- Float file dialogs
hl.window_rule({
    name = "float-file-dialogs",
    match = { title = "^(Open|Save|Save As|File Picker)(.*)$" },
    float = true,
    center = true,
    size = "800 600",
})

hl.window_rule({
    name = "float-wifi",
    match = { title = "wifi" },
    float = true,
    center = true,
    size = "800 500",
})

hl.window_rule({
    name = "float-bluetooth",
    match = { title = "bluetooth" },
    float = true,
    center = true,
    size = "800 500",
})

hl.window_rule({
    name = "postimg-browser",
    match = { title = "^(.*)Google Chrome for Testing(.*)$" },
    workspace = "7 silent",
})

-- Waybar Glass Blur Rules
hl.layer_rule({
    name = "blur",
    match = { namespace = "waybar" },
})
hl.layer_rule({
    name = "ignorezero",
    match = { namespace = "waybar" },
})

-- Quickshell Islandbar Blur Rules
hl.layer_rule({
    name = "blur",
    match = { namespace = "islandbar" },
})
hl.layer_rule({
    name = "ignorezero",
    match = { namespace = "islandbar" },
})

-- PCManFM Acrylic Transparency & Blur Rule
hl.window_rule({
    name = "pcmanfm-transparency",
    match = { class = "^(pcmanfm)$" },
    opacity = "0.85 override 0.85 override",
    no_dim = true,
})

-- Dolphin Acrylic Transparency & Blur Rule
-- Note: blur for windows is set in windowrules.conf (Lua API does not expose blur field)
hl.window_rule({
    name = "dolphin-transparency",
    match = { class = "^(org.kde.dolphin)$" },
    opacity = "0.85 override 0.85 override",
    no_dim = true,
})
