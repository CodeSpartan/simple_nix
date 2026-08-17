# Machine-specific settings -- edit this file when setting up a new PC
{
  username = "ashberry";
  # homeDir is derived as /home/${username} in flake.nix
  hostname = "nixos";
  timezone = "Europe/Dublin";
  defaultLocale = "en_US.UTF-8";
  regionalLocale = "en_IE.UTF-8";    # metric, euro, A4, 24h clock
  tmpfsSize = "1G";                 # ~half of RAM for build tmpfs
  steamScaling = "1.5";         # HiDPI scaling for Steam (match monitor scale)
  cursorSize = 24;                   # cursor size (scale with DPI: 16@1x, 24@1.5x, 32@2x)
  nvidia = false;                     # set false on AMD/Intel GPU machines
  repoDir = "/home/ashberry/code/simple_nix";   # local clone path for the update check; must match username above
  updateCheck = false;                # fetch origin/main nightly and notify; never pull or rebuild
  amduprof = false;                   # AMD uProf -- requires one-time tarball setup, see README
  nsightGraphics = false;             # NVIDIA Nsight Graphics CLI -- requires one-time installer setup, see README
}
