# Machine-specific settings -- edit this file when setting up a new PC
{
  username = "vervain";
  # homeDir is derived as /home/${username} in flake.nix
  hostname = "nixos";
  timezone = "Europe/Moscow";
  defaultLocale = "en_US.UTF-8";
  regionalLocale = "ru_RU.UTF-8";    # metric, 24h clock
  tmpfsSize = "16G";                 # ~half of RAM for build tmpfs
  steamScaling = "2";            # HiDPI scaling for Steam (match monitor scale)
  cursorSize = 32;                   # cursor size (scale with DPI: 16@1x, 24@1.5x, 32@2x)
  nvidia = true;                      # set false on AMD/Intel GPU machines
  repoDir = "/home/vervain/code/simple_nix";   # local clone path for the update check; must match username above
  updateCheck = true;                 # fetch origin/main nightly and notify; never pull or rebuild
  amduprof = false;                   # AMD uProf -- requires one-time tarball setup, see README
  nsightGraphics = false;             # NVIDIA Nsight Graphics CLI -- requires one-time installer setup, see README
}
