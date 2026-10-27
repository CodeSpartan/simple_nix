# Apps that always bypass iVPN, however they are launched.
#
# The list itself is NOT here: it is ~/.config/ivpn-bypass/apps (linked from
# config/ivpn-bypass/apps by link.sh) and is re-read live -- edit and save,
# no rebuild. This module only installs the watcher (ivpn-bypass.py).
#
# Needs iVPN split tunnel on, once: `ivpn splittun -on` (normal mode, not
# inverse). Logs: `journalctl -u ivpn-bypass -f`.
{ pkgs, host, ... }:
{
  systemd.services.ivpn-bypass = {
    description = "Keep listed apps outside the iVPN tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [ "ivpn-service.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 -u ${./ivpn-bypass.py} ${host.homeDir}/.config/ivpn-bypass/apps";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
