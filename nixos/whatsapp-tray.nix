# WhatsApp tray icon (pkgs/whatsapp-tray): a white WhatsApp icon among the
# other tray icons while the Brave PWA is open, with a red dot for messages
# that arrived while it wasn't focused. A user service so it restarts if it
# dies (e.g. when Hyprland restarts).
{ pkgs, ... }:

let
  whatsappTray = pkgs.callPackage ./pkgs/whatsapp-tray { };
in
{
  systemd.user.services.whatsapp-tray = {
    description = "WhatsApp tray icon with unread dot";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${whatsappTray}/bin/whatsapp-tray";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
