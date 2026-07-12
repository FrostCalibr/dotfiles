-- Plugins configuration (ported from modules/plugins.conf)

-- Autoload enabled plugins on startup
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload -n")
end)

if hl.plugin and hl.plugin.hyprexpo then
    hl.config({
        plugin = {
            hyprexpo = {
                columns = 3,
                gaps_in = 5,
                gaps_out = 0,
                bg_col = "rgb(111111)",
                workspace_method = "center current", -- [center/first] [workspace] [gravity] [select] [current]

                -- enable_gesture = true, -- laptop touchpad
                -- gesture_fingers = 3,  -- 3 or 4
                -- gesture_distance = 300, -- how far is the "glance"
                -- gesture_positive = true, -- positive = swipe down. Negative = swipe up.
            },
        },
    })
end
