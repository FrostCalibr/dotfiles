-- Input configuration (ported from modules/input.conf)

hl.config({
    input = {
        kb_layout = "us",
        kb_options = "caps:escape",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            tap_and_drag = true,
            disable_while_typing = true,
            scroll_factor = 0.5, -- slow scroll down if needed
        },
    },
    gestures = {
        workspace_swipe_invert = false,
        workspace_swipe_distance = 300,
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.device({
    name = "elan0712:00-04f3:30fd-touchpad",
    enabled = true,
})

hl.device({
    name = "elan0712:00-04f3:30fd-mouse",
    enabled = true,
})

hl.device({
    name = "usb-optical-mouse-",
    sensitivity = 0,
    accel_profile = "flat",
})
