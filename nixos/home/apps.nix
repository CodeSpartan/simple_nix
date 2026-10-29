{ lib, host, pkgs, config, ... }:

let
  # Discord's voice engine decodes H.264 streams with OpenH264 2.5.1, but its
  # startup cleanup deletes that file as "unused" (keeps only 2.7.0), so
  # watched streams show no video (error 2012). Put it back whenever it goes.
  # Same Cisco binary Discord itself downloads.
  discordOpenh264 = pkgs.fetchurl {
    url = "http://ciscobinary.openh264.org/libopenh264-2.5.1-linux64.7.so.bz2";
    hash = "sha256-guQ224YGQz4/gjx//zJpxDs7o/ElEKhR73sVa4CtGxE=";
  };
  discordOpenh264Dir = "${config.home.homeDirectory}/.var/app/com.discordapp.Discord/config/discord/discord_asset_cache/openh264";
  discordOpenh264Restore = pkgs.writeShellScript "discord-openh264-restore" ''
    f=${discordOpenh264Dir}/libopenh264-2.5.1-linux64.7.so
    [ -d ${discordOpenh264Dir} ] || exit 0
    [ -s "$f" ] && exit 0
    ${pkgs.bzip2}/bin/bzcat ${discordOpenh264} > "$f.tmp" && mv "$f.tmp" "$f"
  '';
in
{
  # Desktop entry for glow (terminal markdown viewer) so file managers can open .md files
  xdg.desktopEntries.glow = {
    name = "Glow";
    exec = "kitty --title Glow glow -p %f";
    terminal = false;
    mimeType = [ "text/markdown" "text/x-markdown" ];
  };

  # --- Dotfile deployments (edit in repo, then nixos-rebuild switch) ---
  xdg.configFile."mc/ini".source = ../../config/mc/ini;
  xdg.configFile."mc/bat-viewer.sh" = { source = ../../config/mc/bat-viewer.sh; executable = true; };
  xdg.dataFile."mc/skins/ayu-dark.ini".source = ../../config/mc/skins/ayu-dark.ini;

  # Discord Flatpak overrides.
  # /nix/store read-only: discord-flags.conf below is a symlink into the store,
  # which the sandbox otherwise can't see (the flags were silently ignored).
  # NVIDIA: force XWayland (GBM can't init inside Flatpak sandbox).
  # TODO: drop the NVIDIA part when NVIDIA GBM works inside Flatpak sandbox
  home.file.".local/share/flatpak/overrides/com.discordapp.Discord".text = ''
    [Context]
    filesystems=/nix/store:ro
  '' + lib.optionalString host.nvidia ''

    [Environment]
    ELECTRON_OZONE_PLATFORM_HINT=x11
  '';
  # Flags the Flatpak's launcher passes to Discord. Autoscroll = middle-click
  # scroll widget, like Brave/Chrome (programs.nix).
  home.file.".var/app/com.discordapp.Discord/config/discord-flags.conf".text = ''
    --enable-blink-features=MiddleClickAutoscroll
  '' + lib.optionalString host.nvidia ''
    --ignore-gpu-blocklist
    --ozone-platform=x11
  '';

  # Restores OpenH264 2.5.1 for Discord (see discordOpenh264 above).
  systemd.user.services.discord-openh264 = {
    Unit.Description = "Restore OpenH264 2.5.1 that Discord deletes";
    Service = { Type = "oneshot"; ExecStart = "${discordOpenh264Restore}"; };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.paths.discord-openh264 = {
    Unit.Description = "Watch Discord's OpenH264 folder";
    Path.PathChanged = discordOpenh264Dir;
    Install.WantedBy = [ "default.target" ];
  };
}
