#!/usr/bin/env bash
# Keeps the monitor on while VLC is playing, even in a window. VLC 3 sends no
# idle-inhibit on Wayland, but reports Playing/Paused over MPRIS. While it plays
# we hold a systemd "idle" lock, which hypridle respects.
# Autostarted from user.lua; check with: systemd-inhibit --list

pid=""
release() { [ -n "$pid" ] && kill "$pid" 2>/dev/null; pid=""; }
trap 'release; exit' INT TERM EXIT

# --follow prints the status on every change (empty line when VLC closes).
while read -r status; do
    if [ "$status" = "Playing" ]; then
        if [ -z "$pid" ]; then
            systemd-inhibit --what=idle --who=VLC --why="Playing video" sleep infinity &
            pid=$!
        fi
    else
        release
    fi
done < <(playerctl --player=vlc --follow status 2>/dev/null)
