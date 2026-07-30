# Periodic, notification-only check for upstream config changes.
#
# Fetches origin/main and notifies the user if the local branch is behind.
# It never pulls commits, updates flake inputs, rebuilds, or activates NixOS.
#
# Enabled by default (host.updateCheck = true). Set to false in host.nix to disable.
{ lib, pkgs, host, ... }:

let
  checkScript = pkgs.writeShellScript "nixos-update-check" ''
    set -euo pipefail

    cd "${host.repoDir}"
    # Use an absolute SSH path because system services have a minimal PATH.
    # Batch mode prevents an unattended check from waiting for a password prompt.
    ${pkgs.git}/bin/git \
      -c core.sshCommand="${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=15" \
      fetch --quiet origin main

    behind=$(${pkgs.git}/bin/git rev-list --count HEAD..origin/main)
    if [ "$behind" -eq 0 ]; then
      ${pkgs.coreutils}/bin/rm -f "${host.homeDir}/.local/state/nixos-update-available"
      exit 0
    fi

    msg="NixOS config is $behind commit(s) behind origin/main. Review: cd ${host.repoDir} && git log --oneline HEAD..origin/main"

    ${pkgs.coreutils}/bin/mkdir -p "${host.homeDir}/.local/state"
    echo "$msg" > "${host.homeDir}/.local/state/nixos-update-available"

    # Best-effort desktop notification
    uid=$(${pkgs.coreutils}/bin/id -u)
    if [ -S "/run/user/$uid/bus" ]; then
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        ${pkgs.libnotify}/bin/notify-send -u normal \
          "NixOS Config Update Available" \
          "$behind new commit(s) on origin/main"
    fi
  '';
in
{
  systemd.services.nixos-update-check = lib.mkIf host.updateCheck {
    description = "Check for upstream NixOS config updates";
    environment.HOME = host.homeDir;
    serviceConfig = {
      Type = "oneshot";
      User = host.username;
      ExecStart = checkScript;
    };
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  systemd.timers.nixos-update-check = lib.mkIf host.updateCheck {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
