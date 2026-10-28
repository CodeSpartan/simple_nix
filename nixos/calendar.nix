# Day notes calendar (replaces Rainlendar from Windows), all local.
#
# - GNOME Calendar is the editor: click a day in the month view to add a note.
#   It stores events through Evolution Data Server (EDS) in plain .ics files,
#   ~/.local/share/evolution/calendar/system/calendar.ics for "Personal".
# - `calendar-notes` (pkgs/calendar-notes) reads those files for the Wayle bar
#   module next to the clock and for the morning notification below.
# - Rainlendar data was copied once with
#   `calendar-notes import-rainlendar <Default.ics>`.
{ pkgs, ... }:

let
  calendarNotes = pkgs.writers.writePython3Bin "calendar-notes" {
    libraries = with pkgs.python3Packages; [ icalendar recurring-ical-events ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./pkgs/calendar-notes/calendar-notes.py);

  # What the bar's clock and calendar icon run on click. GNOME Calendar
  # aborts if it can't resolve the timezone, which happens when it inherits
  # an environment without TZDIR (e.g. a bar restarted from a bare shell).
  calendarOpen = pkgs.writeShellScriptBin "calendar-open" ''
    export TZDIR=''${TZDIR:-/etc/zoneinfo}
    # Always start on the month view (it reopens in the last-used view).
    ${pkgs.dconf}/bin/dconf write /org/gnome/calendar/active-view "'month'"
    exec ${pkgs.gnome-calendar}/bin/gnome-calendar "$@"
  '';
in
{
  services.gnome.evolution-data-server.enable = true;

  environment.systemPackages = [
    pkgs.gnome-calendar
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
    path = [ pkgs.libnotify pkgs.systemd ];
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
