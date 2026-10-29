-- WORKFLOW CHEATSHEET:
--
-- Apps:
--   Super+Q              = kitty
--   Super+R              = rofi launcher
--   Super+E              = file manager
--
-- Windows:
--   Super+C              = close window
--   Super+F              = zoom in (multi-window workspace)
--   Super+Shift+F        = true fullscreen (hides bar)
--   Super+V              = toggle floating
--   Super+J              = toggle split direction
--   Super+arrows         = move focus
--   Super+Shift+arrows   = swap tile positions
--   Super+Ctrl+arrows    = resize tiles
--   Super+Alt+arrows     = nudge floating window (40px)
--   Super+Alt+C          = center floating window
--   Super+drag           = move floating window
--   Super+right-drag     = resize floating window
--
-- Workspaces:
--   Super+1-9            = jump to workspace
--   Super+Shift+1-9      = move window to workspace
--   Super+scroll          = cycle workspaces
--   Super+`              = show desktop (press again to go back)
--   Super+S              = toggle scratchpad
--   Super+M              = toggle layout (dwindle/master)
--   Alt+Tab              = window picker (rofi)
--
-- Utilities:
--   Super+Space / Ctrl+Shift = switch keyboard (US/RU)
--   Super+P              = toggle pseudo tiling
--   Super+L              = lock screen
--   Super+/              = keybind cheatsheet
--   Super+N              = notification history (full bodies)
--   Super+Ctrl+S         = move window to scratchpad
--   Print                = screenshot region
--   Super+Shift+S        = screenshot region
--   Super+Print          = screenshot full monitor


local configDir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Catch-all so the scale applies to whatever output the monitor lands on.
-- Connector names (DP-1 vs DP-4) shuffle across reboots on this multi-GPU box,
-- so pinning to one port left the display at scale 1.0 after a reboot.
-- highrr keeps max refresh (4K panels often report 4K60 as preferred).
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = 2,
})

-- The LG, matched by description (stable, unlike the port name), with its
-- calibration profile. A specific rule replaces the catch-all rather than
-- merging with it, so it repeats mode/position/scale. The ICC forces the
-- sRGB transfer function and doesn't mix with HDR gaming.
hl.monitor({
    output   = "desc:LG Electronics LG ULTRAGEAR+ 307NTRLFX550",
    mode     = "highrr",
    position = "auto",
    scale    = 2,
    -- No `icc` here: Hyprland's ICC conversion crushes everything below
    -- level 16 to black, even with a no-op copy of the profile (dark-room
    -- tests 2026-10-27; Windows shows from 6). The profile's calibration
    -- curve is loaded by vcgt-loader in AUTOSTART instead, like Windows does.
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    -- Essential services
    hl.exec_cmd("wayle shell")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hyprsunset -i")   -- night light daemon, starts off; toggled by nightlight.sh
    -- Monitor calibration curve (white balance) from the LG's ICC profile,
    -- without Hyprland's ICC conversion -- see the monitor rule above.
    hl.exec_cmd("vcgt-loader " .. configDir .. "/lg-ultragear-srgb-d65.icm 'LG ULTRAGEAR'")
    hl.exec_cmd("hypridle")   -- monitor off after 15 min idle (no lock), see hypridle.conf
    hl.exec_cmd(configDir .. "/vlc-idle-inhibit.sh")  -- keep monitor on while VLC plays (windowed too)
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")

    hl.exec_cmd("flameshot")   -- tray daemon; `flameshot gui` exits 1 without it

    -- Remembers the keyboard layout per window (like Windows): switching
    -- windows restores whatever layout was last used in that window.
    -- Per-app defaults for new windows: config/hyprland-per-window-layout/
    hl.exec_cmd("hyprland-per-window-layout")

    -- Polkit agent (for admin password prompts)
    hl.exec_cmd("lxqt-policykit-agent")
end)

-- No notification popups over true fullscreen (Super+Shift+F, games).
-- Hyprland only hides top-layer surfaces that already exist when a window
-- goes fullscreen, so a popup that appears later still draws on top. Instead,
-- switch wayle's Do Not Disturb on while the focused workspace has a true
-- fullscreen window (mode 2/3; maximize = 1 doesn't count). Missed
-- notifications still go to the bell list. If DND was already on by hand,
-- leave it alone: the marker file records that *we* turned it on.
local dnd_marker = "$XDG_RUNTIME_DIR/hypr-fullscreen-dnd"
local dnd_call = "busctl --user call com.wayle.Notifications1 /com/wayle/Notifications com.wayle.Notifications1 SetDnd b "
-- `test`, not `[ ]`: Hyprland reads a leading [...] in exec as window rules.
local dnd_on_cmd = "test \"$(busctl --user get-property com.wayle.Notifications1 /com/wayle/Notifications com.wayle.Notifications1 Dnd)\" = 'b false' && "
    .. dnd_call .. "true && touch " .. dnd_marker
local dnd_off_cmd = "test -e " .. dnd_marker .. " && rm -f " .. dnd_marker .. " && " .. dnd_call .. "false"
local fullscreen_dnd = false

local function update_fullscreen_dnd()
    local ws = hl.get_active_workspace()
    local fs = false
    if ws then
        for _, w in ipairs(hl.get_workspace_windows(ws)) do
            if (w.fullscreen or 0) >= 2 then fs = true break end
        end
    end
    if fs ~= fullscreen_dnd then
        fullscreen_dnd = fs
        hl.exec_cmd(fs and dnd_on_cmd or dnd_off_cmd)
    end
end

-- No "window.destroy": Hyprland fires it from window teardown at exit, after
-- the workspaces are already freed, and hl.get_workspace_windows() then
-- segfaults (0.56.2) -- that crash broke logging out. "window.close" already
-- covers a fullscreen window going away.
for _, ev in ipairs({ "window.fullscreen", "window.active", "window.close",
                      "window.move_to_workspace", "workspace.active", "monitor.focused" }) do
    hl.on(ev, update_fullscreen_dnd)
end


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- NOTE: keep cursor size in sync with cursorSize in nixos/host.nix
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- NOTE: GDK_SCALE must be integer; GDK_DPI_SCALE = monitorScale / GDK_SCALE
-- Adjust both when changing monitor scale (hl.monitor above)
hl.env("GDK_SCALE", "2")
hl.env("GDK_DPI_SCALE", "1.0")
-- NOTE: keep in sync with qt settings in nixos/home/theming.nix
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "breeze")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },

    cursor = {
        no_hardware_cursors = true,
    },

    render = {
        expand_undersized_textures = true,
    },
})


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission({ binary = "/usr/(bin|local/bin)/grim", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm", type = "plugin", mode = "allow" })


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 7,

        border_size = 2,

        col = {
            active_border   = "rgb(FF8F40)",
            inactive_border = "rgb(1A1D23)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = true,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled        = true,
            range          = 12,
            render_power   = 2,
            color          = "rgba(FF8F4033)",
            color_inactive = "rgba(0B0E1400)",
        },

        blur = {
            enabled           = true,
            size              = 3,
            passes            = 4,
            new_optimizations = true,

            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
    dwindle = {
        preserve_split = true, -- You probably want this
    },

    misc = {
        force_default_wallpaper    = 0,
        disable_hyprland_logo      = true,
        vrr                        = 2,    -- G-Sync in fullscreen games only
        focus_on_activate          = true, -- clicking notifications switches to that workspace+window
        initial_workspace_tracking = 2,    -- open windows on the workspace they were launched from, including late child windows
        on_focus_under_fullscreen  = 0,    -- keep current window fullscreen when another window spawns; new one opens behind
    },

    input = {
        -- NOTE: keep in sync with services.xserver.xkb in nixos/desktop.nix
        kb_layout  = "us,ru",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:win_space_toggle",   -- Ctrl+Shift switching is the release binds below
        kb_rules   = "",

        numlock_by_default = true,

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification (ignored by the custom curve below).

        -- Windows "Enhance pointer precision" curve for the G300s (1750 DPI, 1000 Hz,
        -- Windows slider 16/20). Generated by: python3 scripts/windows-mouse-curve.py 16
        -- (higher number = faster). "adaptive" is libinput's default if this ever annoys.
        accel_profile = "custom 0.25 0.000 0.228 0.455 0.683 0.910 1.138 1.365 1.705 2.047 2.390 2.732 3.074 3.417 3.759 4.101 4.443 4.786 5.128 5.559 6.079 6.599 7.119 7.639 8.158 8.678 9.198 9.718 10.238 10.758 11.277 11.797 12.317 12.837 13.357 13.877 14.397 14.916 15.436 15.956 16.476 16.996 17.516 18.035 18.555 19.075 19.595 20.115 20.635 21.155 21.674 22.194 22.714 23.234 23.754 24.274 25.326 26.401 27.475 28.550 29.624 30.699",

        repeat_rate  = 35,
        repeat_delay = 400,

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- Curves, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}  } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}  } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}     } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}  } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}   } })
hl.curve("overshot",       { type = "bezier", points = { {0.13, 0.99}, {0.29, 1.1} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 2,    bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


---------------------
---- KEYBINDINGS ----
---------------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/
local mainMod = "SUPER" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C",         hl.dsp.window.close())
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("ALT + Tab",               hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + slash",     hl.dsp.exec_cmd(configDir .. "/cheatsheet.sh"))
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())                    -- dwindle
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))              -- dwindle
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd(configDir .. "/toggle-layout.sh"))
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("kitty --class=notif-log sh -c 'wayle notify list | less -R'"))

-- Ctrl+Shift switches keyboard layout on *release*, like Windows. XKB's own
-- grp:ctrl_shift_toggle fires on press, so Ctrl+Shift+C/V/T also flipped the
-- layout. Release binds on the modifier keys themselves; whichever of the two
-- is let go first triggers it. The released key still counts as held at that
-- moment, so the mod mask is CTRL + SHIFT (like the documented SUPER + SUPER_L).
local next_layout = hl.dsp.exec_cmd("hyprctl switchxkblayout all next")
for _, k in ipairs({ "Shift_L", "Shift_R" }) do
    hl.bind("CTRL + SHIFT + " .. k, next_layout, { release = true })
end
for _, k in ipairs({ "Control_L", "Control_R" }) do
    hl.bind("CTRL + SHIFT + " .. k, next_layout, { release = true })
end

-- Black screen after a monitor replug: aquamarine 0.15.0 leaves the output at 0x0 and
-- never re-applies the monitor rule (hyprwm/aquamarine#382). A reload re-applies it.
-- locked = true so it also works from the lock screen. Drop this once aquamarine is fixed.
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })

-- Screenshots
hl.bind("Print",                   hl.dsp.exec_cmd("flameshot gui"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grimblast --freeze copysave area"))
hl.bind(mainMod .. " + Print",     hl.dsp.exec_cmd("grimblast copysave output"))

-- Move focus with mainMod + arrow keys
-- Swap window positions with mainMod + SHIFT + arrow keys
-- Resize tiles with mainMod + CTRL + arrow keys
for _, arrow in ipairs({
    { key = "left",  dir = "l", dx = -40, dy =   0 },
    { key = "right", dir = "r", dx =  40, dy =   0 },
    { key = "up",    dir = "u", dx =   0, dy = -40 },
    { key = "down",  dir = "d", dx =   0, dy =  40 },
}) do
    hl.bind(mainMod .. " + " .. arrow.key,           hl.dsp.focus({ direction = arrow.dir }))
    hl.bind(mainMod .. " + SHIFT + " .. arrow.key,   hl.dsp.window.move({ direction = arrow.dir }))
    hl.bind(mainMod .. " + CTRL + " .. arrow.key,
        hl.dsp.window.resize({ x = arrow.dx, y = arrow.dy, relative = true }), { repeating = true })
    -- Floating windows (e.g. Unreal's dialogs that open under the bar)
    hl.bind(mainMod .. " + ALT + " .. arrow.key,
        hl.dsp.window.move({ x = arrow.dx, y = arrow.dy, relative = true }), { repeating = true })
end
hl.bind(mainMod .. " + ALT + C", hl.dsp.window.center())

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end

-- Show desktop: Super+` jumps to an empty workspace named "desktop" (just the
-- wallpaper); pressing it again goes back to the workspace you came from.
local desktop_return = nil
hl.bind(mainMod .. " + grave", function()
    local ws = hl.get_active_workspace()
    if ws and ws.name == "desktop" then
        hl.dispatch(hl.dsp.focus({ workspace = desktop_return or "previous" }))
    else
        desktop_return = ws and ws.id
        hl.dispatch(hl.dsp.focus({ workspace = "name:desktop" }))
    end
end)

-- Brave: Ctrl+scroll over the tab bar switches tabs, like Brave on Windows.
-- On Linux Brave's only control is brave://flags "Change active tab on scroll
-- event": on = plain scroll switches tabs, off = no scroll switching at all.
-- With it off, these binds send Brave Ctrl+PageDown/PageUp when the cursor is
-- in the tab bar (top 40px of the window). non_consuming: the scroll still
-- reaches every app, so Ctrl+scroll zoom keeps working elsewhere.
local brave_tabbar_height = 40
local function brave_tab_scroll(key)
    return function()
        local w = hl.get_active_window()
        local c = hl.get_cursor_pos()
        if not (w and c) or w.class ~= "brave-browser" then return end
        if c.x < w.at.x or c.x > w.at.x + w.size.x
            or c.y < w.at.y or c.y > w.at.y + brave_tabbar_height then return end
        hl.dispatch(hl.dsp.send_shortcut({ mods = "CTRL", key = key }))
    end
end
hl.bind("CTRL + mouse_down", brave_tab_scroll("Next"),  { non_consuming = true })
hl.bind("CTRL + mouse_up",   brave_tab_scroll("Prior"), { non_consuming = true })

-- Scratchpad (hidden overlay workspace)
hl.bind(mainMod .. " + S",        hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Calculator key -> KCalc (floating, "kcalc" window rule)
hl.bind("XF86Calculator", hl.dsp.exec_cmd("kcalc"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Blur the floating panel bar
hl.layer_rule({
    name  = "wayle-bar",
    match = { namespace = "^wayle-bar-" },
    blur  = true,
    xray  = true,
})

-- Rofi launcher -- blur behind
hl.layer_rule({
    name         = "rofi",
    match        = { namespace = "^rofi$" },
    blur         = true,
    ignore_alpha = 0.3,
})

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/ for more
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/ for workspace rules

-- Smart gaps - single window fills screen
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
hl.window_rule({
    name        = "no-gaps-wtv1",
    match       = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})
hl.window_rule({
    name        = "no-gaps-f1",
    match       = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

-- General window rules
-- Apps can't fullscreen/maximize themselves -- except VLC, so its F key and
-- double-click work. ("negative:" inverts the regex. A later rule with a
-- narrower suppress_event does NOT override this one; tested.)
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = "negative:^(vlc)$" },
    suppress_event = "fullscreen maximize",
})

-- Any fullscreen window (movie, game) keeps hypridle from turning the
-- monitor off; the 15-min timer runs again once it leaves fullscreen.
hl.window_rule({
    name         = "idle-inhibit-fullscreen",
    match        = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Telegram's photo/video viewer: open fullscreen. It asks for fullscreen
-- itself, but suppress-maximize-events above ignores that request.
-- Floating: a tiled fullscreen window makes the smart-gaps rules resize the
-- chat window behind it, and Telegram jumps to the chat bottom on close.
hl.window_rule({
    name       = "telegram-media-viewer",
    match      = { class = "^org.telegram.desktop$", title = "^Media viewer$" },
    float      = true,
    fullscreen = true,
})

-- Keep IVPN's main window tiled and let it fill the tile.
hl.window_rule({
    name        = "ivpn-main",
    match       = { class = "^IVPN$", title = "^IVPN Client$" },
    tile        = true,
    no_max_size = true,
})

-- Float utility windows
for _, class in ipairs({
    "^(pavucontrol)$",
    "^(blueman-manager)$",
    "^(nm-connection-editor)$",
    "^(wdisplays)$",
    "^(org.gnome.seahorse.Application)$",
    "^(lxqt-policykit-agent)$",
}) do
    hl.window_rule({ match = { class = class }, float = true })
end

-- Float file dialogs
for _, title in ipairs({
    "^(Open File)$",
    "^(Select a File)$",
    "^(Open Folder)$",
    "^(Save As)$",
    "^(File Upload)$",
    "^(Choose Files)$",
}) do
    hl.window_rule({ match = { title = title }, float = true })
end

-- Flameshot overlay -- reports an empty class, so this has to match on title.
hl.window_rule({
    name    = "flameshot",
    match   = { title = "^flameshot$" },
    float   = true,
    pin     = true,
    size    = { "monitor_w", "monitor_h" },
    move    = { "0", "0" },
    no_anim = true,
})

-- Day-notes calendar (calcurse in foot, opened from the bar by
-- calendar-open): centred floating window.
hl.window_rule({
    name  = "calcurse",
    match = { class = "^calcurse$" },
    float = true,
    size  = { "monitor_w*0.6", "monitor_h*0.65" },
    move  = { "monitor_w*0.2", "monitor_h*0.15" },
})

-- KClock (timer/stopwatch, opened from the bar's clock by clock-open):
-- floating, top-centre under the clock.
hl.window_rule({
    name  = "kclock",
    match = { class = "^org\\.kde\\.kclock$" },
    float = true,
    size  = { "monitor_w*0.3", "monitor_h*0.5" },
    move  = { "monitor_w*0.35", "monitor_h*0.04" },
})

-- KCalc (calculator key): small floating window, centred.
hl.window_rule({
    name   = "kcalc",
    match  = { class = "^org\\.kde\\.kcalc$" },
    float  = true,
    center = true,
})

-- Picture-in-Picture
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture in Picture)$" },
    float = true,
    pin   = true,
    size  = { "monitor_w*0.25", "monitor_h*0.25" },
    move  = { "monitor_w*0.73", "monitor_h*0.72" },
})

-- Steam
-- RE2 does not support negative lookahead, so the old "not Steam" matcher
-- spammed the journal continuously. Keep Steam's main window tiled; add exact
-- utility/dialog titles here if one needs forced floating.
-- hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List|Settings|Properties)$" }, float = true })

-- Gaming - tearing for reduced input latency
hl.window_rule({ match = { class = "^(steam_app_.*)$" }, immediate = true })
hl.window_rule({ match = { class = [[^(.*\.exe)$]] },    immediate = true })

-- XWayland fix
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})
