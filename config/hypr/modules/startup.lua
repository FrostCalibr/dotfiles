-- Startup configuration (ported from modules/startup.conf)

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("quickshell -p ~/.config/quickshell/quickshell-osd")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- cliphist daemon
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
