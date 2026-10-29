#!/bin/sh
# Bar click -> program, launched by Hyprland instead of by Wayle.
# Hyprland's initial_workspace_tracking opens a window on the workspace its
# launching process started on; Wayle started on workspace 1, so programs it
# launches directly always open there. Launched by Hyprland, they open on the
# current workspace.
#
# Usage (Wayle config): left-click = "$HOME/.config/wayle/launch.sh missioncenter"
# Arguments are joined with spaces into one shell command.
cmd=$(printf '%s' "$*" | sed 's/\\/\\\\/g; s/"/\\"/g')
exec hyprctl eval "hl.exec_cmd(\"$cmd\")"
