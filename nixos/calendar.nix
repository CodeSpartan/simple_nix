# Day notes calendar (replaces Rainlendar from Windows), all local.
#
# - calcurse is the calendar: a terminal app, opened from the bar in a small
#   `foot` window (~80 MB while open, nothing running when closed). Data:
#   ~/.local/share/calcurse (`apts` + `notes/`), saved when it quits.
# - `calendar-notes` (pkgs/calendar-notes) asks calcurse for today's notes:
#   the Wayle module next to the clock and the morning notification below.
# - Rainlendar data was loaded once with
#   `calendar-notes import-rainlendar <Default.ics>`.
# (GNOME Calendar was tried first: 1.6 s to open, ~450 MB, plus ~160 MB of
# Evolution Data Server always running.)
{ pkgs, ... }:

let
  calendarNotes = pkgs.writers.writePython3Bin "calendar-notes" {
    libraries = [ pkgs.python3Packages.icalendar ];  # import-rainlendar only
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./pkgs/calendar-notes/calendar-notes.py);

  # Starting settings, copied in only if calcurse has no config yet (its own
  # settings menu rewrites the file). periodicsave: save every minute, so the
  # bar sees new notes while calcurse is still open.
  calcurseConf = pkgs.writeText "calcurse.conf" ''
    general.confirmquit=no
    general.firstdayofweek=monday
    general.periodicsave=1
    general.progressbar=no
    format.inputdate=4
    appearance.calendarview=monthly
  '';

  # What the bar's clock and calendar icon run on click: focus calcurse if
  # it's already open (it refuses to run twice), else open it in foot.
  # Window size/position: "calcurse" rule in config/hypr/user.lua.
  calendarOpen = pkgs.writeShellScriptBin "calendar-open" ''
    conf="''${XDG_CONFIG_HOME:-$HOME/.config}/calcurse/conf"
    if [ ! -s "$conf" ]; then
      mkdir -p "$(dirname "$conf")" && cp ${calcurseConf} "$conf" && chmod 644 "$conf"
    fi
    if ${pkgs.procps}/bin/pgrep -x calcurse >/dev/null; then
      exec hyprctl dispatch 'hl.dsp.focus({ window = "class:^calcurse$" })'
    fi
    exec ${pkgs.foot}/bin/foot --app-id=calcurse \
      -o 'main.font=JetBrainsMono Nerd Font Mono:size=12' \
      -o colors.background=0B0E14 -o colors.foreground=B8B5AC \
      ${pkgs.calcurse}/bin/calcurse
  '';
in
{
  environment.systemPackages = [
    pkgs.calcurse
    calendarNotes
    calendarOpen
  ];

  # Today's notes as a notification, once a day: at the first login of the day
  # and at 08:00 if the PC was already on. The script skips days it already
  # notified and waits for the notification daemon (Wayle) to come up.
  systemd.user.services.calendar-notes-notify = {
    description = "Notify about today's calendar notes";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    path = [ pkgs.libnotify pkgs.systemd pkgs.calcurse ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${calendarNotes}/bin/calendar-notes notify";
    };
  };

  systemd.user.timers.calendar-notes-notify = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 08:00:00";
      Persistent = true;
    };
  };
}
