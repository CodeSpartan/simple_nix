#!/bin/sh
# Toggle "show desktop": hide every window on the active workspace by moving
# it into a dedicated special workspace, or bring them all back if they're
# already hidden there. Hyprland has no built-in "show desktop" dispatcher
# (it's a tiling WM, there's nothing to "minimize" to), so this fakes the
# Windows+D behaviour by round-tripping windows through special:showdesktop.
SPECIAL="special:showdesktop"
WS=$(hyprctl activeworkspace -j | jq -r '.id')

if hyprctl clients -j | jq -e --arg s "$SPECIAL" 'any(.[]; .workspace.name == $s)' >/dev/null; then
    # Already hidden -- restore every window back to the workspace it came from.
    hyprctl clients -j | jq -r --arg s "$SPECIAL" '.[] | select(.workspace.name == $s) | .address' |
        while read -r addr; do
            hyprctl dispatch movetoworkspacesilent "$WS,address:$addr"
        done
else
    # Nothing hidden yet -- stash every window on the current workspace.
    hyprctl clients -j | jq -r --argjson w "$WS" '.[] | select(.workspace.id == $w) | .address' |
        while read -r addr; do
            hyprctl dispatch movetoworkspacesilent "$SPECIAL,address:$addr"
        done
fi
