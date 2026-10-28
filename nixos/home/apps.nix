{ lib, host, ... }:

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
}
