-- Appearance configuration (ported from modules/appearance.conf)

local colors = require("colors")

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 2,

        col = {
            active_border = { colors = { colors.surface_variant, colors.primary }, angle = 20 },
            inactive_border = colors.outline_variant,
        },

        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = colors.shadow,
        },

        blur = {
            enabled = true,
            size = 24,
            passes = 3,
            ignore_opacity = true,

            noise = 0.05,
            contrast = 1.5,
            brightness = 1,

            xray = false,
            new_optimizations = false,
        },
    },
})
