# MAX tray icon (pkgs/max-tray): a white MAX icon among the other tray icons
# while MAX runs, with a red dot while it has unread messages (read from MAX's
# own log). A user service so it restarts if it dies.
{ pkgs, ... }:

let
  maxTray = pkgs.callPackage ./pkgs/max-tray { };
in
{
  systemd.user.services.max-tray = {
    description = "MAX tray icon with unread dot";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${maxTray}/bin/max-tray";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
