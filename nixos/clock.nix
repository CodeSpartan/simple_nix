# Timer / stopwatch / alarms (like the Windows Clock app): KDE's KClock,
# opened by clicking the time in the bar (config/wayle/config.toml).
#
# - kclock is the window; kclockd is the service that runs the timers and
#   rings (on repeat until dismissed). kclockd starts at login (its XDG
#   autostart file) or on demand over D-Bus, and quits by itself when no
#   timer runs, nothing rings, no alarm is enabled and the window is closed.
#   ~12-60 MB while running.
# - Stop a ringing timer: click the notification, its X, or Dismiss in the
#   window. The X works only because of `popup-close-behavior = "remove"`
#   in the Wayle config.
# - The KDE libraries it needs are already installed (KDE theming), so it
#   adds ~5 MB.
# (GNOME Clocks was the other candidate: its timer rings only once.)
{ pkgs, ... }:

let
  # What the bar's clock runs on click: focus KClock if it's already open,
  # else open it on the Timers page. Window rule: "kclock" in
  # config/hypr/user.lua.
  clockOpen = pkgs.writeShellScriptBin "clock-open" ''
    if hyprctl clients | grep -q '^\s*class: org\.kde\.kclock$'; then
      exec hyprctl dispatch 'hl.dsp.focus({ window = "class:^org\\.kde\\.kclock$" })'
    fi
    exec ${pkgs.kdePackages.kclock}/bin/kclock --page Timers
  '';
in
{
  environment.systemPackages = [
    pkgs.kdePackages.kclock
    clockOpen
  ];
}
