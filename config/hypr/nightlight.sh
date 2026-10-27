#!/bin/sh
# Toggle night light (hyprsunset) between off and 4500K.
# Bound to a left-click on the bar's weather widget (config/wayle/config.toml).
#
# hyprsunset is started off (`hyprsunset -i`) by user.lua at login. Its IPC can
# set a temperature but can't report whether one is active, so the on/off
# state lives in a file under $XDG_RUNTIME_DIR -- cleared at reboot, same as
# hyprsunset itself.
TEMP=4500
STATE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nightlight-on"

# Restart the daemon if it died, so the click never silently does nothing.
if ! pgrep -x hyprsunset >/dev/null; then
    hyprsunset -i >/dev/null 2>&1 &
    sleep 0.5
    rm -f "$STATE"
fi

notify() {
    notify-send -t 1500 -h string:x-canonical-private-synchronous:nightlight "$1" "$2"
}

if [ -e "$STATE" ]; then
    hyprctl hyprsunset identity >/dev/null && rm -f "$STATE" && notify "Night light off"
else
    hyprctl hyprsunset temperature "$TEMP" >/dev/null && touch "$STATE" && notify "Night light on" "${TEMP}K"
fi
