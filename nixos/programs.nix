{ config, lib, pkgs, agenix, host, ... }:

let
  # openmp tracks default llvmPackages to match clang; llvmPackages_latest doesn't build.
  mathLibs = with pkgs; [ blis openblas fftw gsl suitesparse eigen llvmPackages.openmp ];
  # Non-Nix desktop/game binaries dlopen these at runtime (via nix-ld):
  # Wayland + xkbcommon (display/input), Vulkan + libglvnd (GPU loaders), alsa-lib (audio), udev (devices).
  desktopRuntimeLibs = with pkgs; [ alsa-lib wayland libxkbcommon udev vulkan-loader libglvnd ];
  # Unreal Engine's prebuilt Linux editor (~/code/UE, zip from
  # unrealengine.com/linux): libraries it loads at runtime (SDL: X11, GTK,
  # PulseAudio, D-Bus) plus what its built-in Chromium (CEF) links against.
  unrealRuntimeLibs = with pkgs; [
    nss nspr glib atk at-spi2-atk at-spi2-core dbus libdrm libgbm expat
    pango cairo gtk3 libpulseaudio fontconfig freetype libayatana-appindicator
    libxcb libx11 libxcomposite libxdamage libxext libxfixes libxrandr
    libxcursor libxi libxscrnsaver libxtst libxrender
    icu openssl krb5   # bundled .NET (UnrealBuildTool) -- dies without ICU
  ];
  # wgpu-utils also ships parsers, examples, xtask helpers and a bug-repro that
  # would clutter PATH. Expose only the two general-purpose CLIs. wgpu-info's
  # wrapper references its target by absolute store path, so symlinks suffice.
  nagaTools = pkgs.runCommand "naga-${pkgs.wgpu-utils.version}" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.wgpu-utils}/bin/naga $out/bin/naga
    ln -s ${pkgs.wgpu-utils}/bin/wgpu-info $out/bin/wgpu-info
  '';

  # VLC 3 is Qt5 and runs under XWayland (its video embedding needs X11).
  # With xwayland force_zero_scaling, XWayland apps must scale themselves, and
  # Qt ignores GDK_SCALE -- so VLC drew its UI at 1x. Wrap it with
  # QT_SCALE_FACTOR=2 (this machine's monitor scale). Not an overlay: that
  # would rebuild everything linking libvlc (e.g. KDE's phonon backend).
  # The .desktop files call the original by absolute path, so repoint them.
  #
  # Also made to look like VLC on Windows: light (Qt's Fusion style with the
  # generic theme, not the KDE dark scheme -- VLC has no theme option of its
  # own) and Segoe UI 9pt menus (Qt's generic theme asks fontconfig for
  # "Sans Serif" 9pt; a VLC-only fontconfig file points that at Segoe UI,
  # copied from the Windows drive -- see CLAUDE.md). The alias goes before the
  # system include so the system's Inter preference doesn't win.
  vlcFonts = pkgs.writeText "vlc-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <alias binding="strong"><family>Sans Serif</family><prefer><family>Segoe UI</family></prefer></alias>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
    </fontconfig>
  '';
  vlcScaled = pkgs.symlinkJoin {
    name = "vlc-${pkgs.vlc.version}-scaled";
    inherit (pkgs.vlc) version;
    # vlc's meta asks for its "man" output too; this join only has "out".
    meta = builtins.removeAttrs pkgs.vlc.meta [ "outputsToInstall" ];
    paths = [ pkgs.vlc ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for b in vlc qvlc; do
        rm "$out/bin/$b"
        makeWrapper "${pkgs.vlc}/bin/$b" "$out/bin/$b" --set QT_SCALE_FACTOR 2 \
          --set QT_QPA_PLATFORMTHEME generic --set QT_STYLE_OVERRIDE Fusion \
          --set FONTCONFIG_FILE ${vlcFonts}
      done
      for d in "$out"/share/applications/*.desktop; do
        src=$(readlink -f "$d"); rm "$d"
        sed "s|${pkgs.vlc}/bin/|$out/bin/|g" "$src" > "$d"
      done
    '';
  };

  # In Tun mode sing-box owns the tunnel and hands proxied traffic to xray,
  # but v2rayN still copied "Process" routing rules into xray's config; xray
  # can't see sing-box's (root) sockets, so it logged "no process found"
  # for every connection. The patch leaves such rules out of xray's config
  # in that setup (they could never match there; sing-box applies them).
  v2raynPatched = pkgs.v2rayn.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./overlays/v2rayn-skip-process-rules-in-xray.patch ];
  });
  # Middle-click autoscroll (the little scroll widget, as on Windows). Off by
  # default on Linux, where middle-click pastes; this Blink flag turns it on.
  # Middle-click in text fields still pastes, on links still opens a tab.
  # Loads the monitor's ICC calibration curve (see config/hypr/user.lua).
  vcgtLoader = pkgs.callPackage ./pkgs/vcgt-loader { };

  # Image viewer (default for images, see xdg.mime below).
  # - Unsets LD_LIBRARY_PATH: apps Brave opens (downloads) inherit Brave's
  #   wrapper's one, with Brave's own Qt/Wayland libs -- imv froze with it.
  # - default.ini next to the binary = nomacs' first-run settings (wheel
  #   switches images, Ctrl+wheel zooms, dark theme, ...).
  nomacsTuned = pkgs.nomacs.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.makeWrapper ];
    postInstall = (old.postInstall or "") + ''
      install -Dm644 ${../config/nomacs/default.ini} $out/bin/default.ini
    '';
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/nomacs --unset LD_LIBRARY_PATH
    '';
  });
  braveAutoscroll = pkgs.brave.override {
    commandLineArgs = "--enable-blink-features=MiddleClickAutoscroll";
  };
  chromeAutoscroll = pkgs.google-chrome.override {
    commandLineArgs = "--enable-blink-features=MiddleClickAutoscroll";
  };
  # Discord is Electron, so the same flag works (Flatpak Discord: home/apps.nix).
  discordPtbAutoscroll = pkgs.discord-ptb.override {
    commandLineArgs = "--enable-blink-features=MiddleClickAutoscroll";
  };

  # v2rayN is an Avalonia (.NET) app on XWayland; same force_zero_scaling
  # story as VLC, so it drew at 1x. Avalonia's own scale knob fixes it.
  # Its .desktop file runs plain `v2rayN` from PATH, so no repointing.
  v2raynScaled = pkgs.symlinkJoin {
    name = "v2rayn-${v2raynPatched.version}-scaled";
    inherit (v2raynPatched) version meta;
    paths = [ v2raynPatched ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/v2rayN"
      makeWrapper "${v2raynPatched}/bin/v2rayN" "$out/bin/v2rayN" \
        --set AVALONIA_GLOBAL_SCALE_FACTOR 2
    '';
  };

  # Opened from Brave (.torrent / magnet), qBittorrent inherits Brave's
  # LD_LIBRARY_PATH and comes up with no tray icon -- closing the window
  # then leaves it running invisibly. Same fix as nomacsTuned.
  qbittorrentClean = pkgs.symlinkJoin {
    name = "qbittorrent-${pkgs.qbittorrent.version}-clean-env";
    inherit (pkgs.qbittorrent) version meta;
    paths = [ pkgs.qbittorrent ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/qbittorrent"
      makeWrapper "${pkgs.qbittorrent}/bin/qbittorrent" "$out/bin/qbittorrent" \
        --unset LD_LIBRARY_PATH
    '';
  };
in

{
  # --- Development ---
  programs.direnv.enable = true;        # Auto-load .envrc per-directory environments
  programs.nix-ld.enable = true;        # Dynamic linker for non-Nix binaries (Mason, uv, pip wheels)
  programs.nix-ld.libraries = desktopRuntimeLibs ++ unrealRuntimeLibs;
  programs.firefox.enable = true;       # Firefox browser

  # --- Gaming ---
  programs.gamemode.enable = true;      # CPU governor + scheduler optimization while gaming
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;     # Steam Deck-like session selectable at SDDM login
    extraCompatPackages = [ pkgs.proton-ge-bin ];   # Proton-GE for better game compatibility
    package = pkgs.steam.override {
      extraEnv = {
        STEAM_FORCE_DESKTOPUI_SCALING = host.steamScaling;
      };
    };
  };

  # AppImages (e.g. Epic Games Launcher Preview, ~/Applications/) expect a
  # normal Linux file layout; this runs them in one (appimage-run) and lets
  # them be started directly, like on Ubuntu.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # --- Mission Center extras ---
  # Mission Center offers a "missioncenter-magpie-setup" script (pkexec) that
  # setcaps nethogs and writes /etc/udev/rules.d -- neither works on NixOS
  # (read-only store, generated /etc, no /usr/bin/chmod), so it fails on
  # every retry. Same two things, done declaratively:
  #  - per-process network usage: nethogs with the capabilities it needs,
  #    via a /run/wrappers/bin wrapper (first on PATH).
  #  - CPU power draw: make RAPL energy counters readable (root-only by
  #    default since the 2020 PLATYPUS side-channel; fine on a one-user box).
  security.wrappers.nethogs = {
    source = "${pkgs.nethogs}/bin/nethogs";
    capabilities = "cap_net_admin,cap_net_raw,cap_dac_read_search,cap_sys_ptrace+pe";
    owner = "root";
    group = "root";
  };
  services.udev.extraRules = ''
    SUBSYSTEM=="powercap", KERNEL=="intel-rapl*", RUN+="${pkgs.coreutils}/bin/chmod a+r /sys/%p/energy_uj"
  '';

  # --- Services ---
  # Rootless Docker can't resolve DNS because NixOS's resolv.conf symlink chain
  # goes through /nix/store, which slirp4netns sandboxes away.
  # For VPN-internal hostnames (e.g. private mirrors), use --network host.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
    daemon.settings.dns = [ "1.1.1.1" "8.8.8.8" ];
  };
  virtualisation.podman.enable = true;
  programs.gpu-screen-recorder.enable = true;   # NVENC screen recorder + setcap gsr-kms-server wrapper
  services.flatpak.enable = true;       # Flatpak for apps that need it (e.g. Discord with Krisp)
  services.ivpn.enable = true;          # ivpn-service daemon; without it the CLI/UI have no /etc/opt/ivpn/mutable
  # Starts at boot (module default, multi-user.target) -- this user wants the
  # CLI/UI usable immediately rather than having to `systemctl start` it by
  # hand first. Trade-off: the daemon polls iVPN's server list hourly even
  # while logged out. Set back to `lib.mkForce [ ]` if that matters more.
  services.ratbagd.enable = true;       # Gaming-mouse config daemon that Piper talks to (Logitech G300s)
  services.printing = {
    enable = true;
    browsing = false;                  # Don't advertise printers on the network
  };

  # Default apps: images -> nomacs, torrents/magnet links -> qBittorrent
  # (system-wide /etc/xdg/mimeapps.list; a choice made
  # in a file manager's "Open With" still wins for that user).
  xdg.mime.defaultApplications = lib.genAttrs [
    "image/avif" "image/bmp" "image/gif" "image/heic" "image/heif" "image/jpeg"
    "image/jxl" "image/png" "image/tiff" "image/webp" "image/x-eps" "image/x-ico"
    "image/x-portable-bitmap" "image/x-portable-graymap" "image/x-portable-pixmap"
    "image/x-xbitmap" "image/x-xpixmap"
  ] (_: "org.nomacs.ImageLounge.desktop") // {
    "application/x-bittorrent" = "org.qbittorrent.qBittorrent.desktop";
    "x-scheme-handler/magnet" = "org.qbittorrent.qBittorrent.desktop";
  };

  # --- System Packages ---
  environment.systemPackages = with pkgs; [
    chromeAutoscroll           # Chrome browser, middle-click autoscroll on (bypasses iVPN: see config/ivpn-bypass/apps)
    discordPtbAutoscroll       # Second Discord instance (PTB), middle-click autoscroll on (own login), alongside the Flatpak Discord. Flathub has no PTB.

    # Core utilities
    git-filter-repo gh glab wget curl unzip p7zip file fastfetch optipng
    bc                         # Arbitrary-precision command-line calculator
    kdePackages.kcalc          # Calculator (keyboard's calculator key, see config/hypr/user.lua)
    imagemagick                # Image conversion/resizing (convert, mogrify)
    poppler-utils              # PDF utilities (pdftotext, pdfimages, pdfinfo)
    ffmpeg                     # Audio/video transcoding and processing
    age                        # age encryption (used by agenix for key management)
    agenix.packages.${pkgs.stdenv.hostPlatform.system}.default   # age secret management CLI

    # Modern CLI replacements & tools
    bat                        # cat alternative (syntax highlighting, git integration)
    cloc                       # count lines of code by language
    duf                        # df alternative (disk usage with colors)
    fd                         # find alternative
    ripgrep                    # grep alternative
    fzf                        # Fuzzy finder (used by shell, nvim, etc.)
    delta                      # Better git diffs
    jq                         # JSON processor
    xxd                        # Hex dump
    binwalk                    # Firmware image analysis and extraction
    sqlite                     # sqlite3 CLI for inspecting .sqlite files
    htop                       # Process viewer
    tree                       # Directory listing as tree
    psmisc                     # killall, pstree
    procps                     # pgrep, pkill, ps
    lsof                       # List open files/sockets by process
    lm_sensors                 # `sensors` -- hwmon readout (Tctl, per-CCD temps, fans)
    parallel                   # GNU parallel -- run jobs concurrently from lists/pipes
    tmux                       # Terminal multiplexer
    mc                         # Midnight Commander file manager
    ntfs3g                     # NTFS filesystem support
    exfatprogs                 # exFAT filesystem support (mkfs.exfat, fsck.exfat)
    efibootmgr                 # Manage UEFI NVRAM boot entries
  ] ++ lib.optionals host.nvidia [
    nvtopPackages.nvidia       # GPU process monitoring
  ] ++ [
    zstd                       # Fast compression (used by kernel, packing, etc.)
    yq-go                      # jq for YAML/TOML files
    just                       # Modern make alternative for project commands

    # Terminal & editors
    kitty neovim kdePackages.kate

    # Python
    python3 uv ruff jupyter                 # jupyter: notebook + jupyterlab, `jupyter notebook` / `jupyter lab`

    # Rust
    rustc cargo rust-analyzer cargo-nextest

    # Go
    go gopls

    # JVM
    jdk kotlin kotlin-language-server

    # Haskell
    ghc cabal-install haskell-language-server

    # Lean: removed until nixpkgs fixes lean4 -- cmake 4.4 broke its stage install prefix.

    # Idris
    idris2 idris2Packages.idris2Lsp

    # C/C++ / CUDA
    gnumake cmake ninja gcc clang
    clang-tools                # clangd LSP
    bear                       # Records a build into compile_commands.json so clangd works on non-CMake projects
    llvmPackages_latest.llvm   # LLVM tools (opt, llvm-ar, llvm-nm, etc.)
    llvmPackages_latest.lld    # LLVM linker
    llvmPackages_latest.lldb   # LLVM debugger
    gdb                        # GNU debugger (core dumps, rust-gdb pretty-printers; cuda-gdb ships with cudatoolkit)
    pkg-config                 # Library metadata resolver (used by cmake/autotools/cargo)
    sccache                    # Compiler cache for C/C++/CUDA (via CMake launcher). Skipped for Rust -- conflicts with incremental compilation.
    mold                       # Fast parallel linker; opt-in per-project via -fuse-ld=mold or .cargo/config.toml
    conan                      # C/C++ package manager
    vcpkg                      # Microsoft C/C++ package manager
    vcpkg-tool                 # vcpkg standalone tool
    doxygen                    # API doc generator (uses graphviz for call/dep graphs)
    tree-sitter                # Treesitter CLI (nvim-treesitter parser compilation)
    cudaPackages_13_2.cudatoolkit     # CUDA 13.2 -- Blackwell sm_120 supported, driver >=580 required
    cudaPackages_13_2.cudnn           # cuDNN (GPU-accelerated deep learning primitives)
    cudaPackages_13_2.nsight_compute  # ncu -- kernel-level GPU profiler
    cudaPackages_13_2.nsight_systems  # nsys -- system-wide GPU/CPU timeline profiler
    cudaPackages_13_2.cuda_nsight     # nsight -- Eclipse-based CUDA IDE/debugger

    # Numerical / math libraries (CPU)
    blis                       # BLAS tuned for Zen (matches/beats MKL on Ryzen)
    openblas                   # BLAS + LAPACK (bundles cblas.h/libcblas, lapacke)
    fftw                       # FFT (double precision)
    eigen                      # Header-only C++ linear algebra
    gsl                        # GNU Scientific Library
    suitesparse                # Sparse linear algebra (UMFPACK, CHOLMOD, etc.)

    # Node/TypeScript
    nodejs typescript bun

    # .NET -- MMOKit's PersistenceServer (net8.0, ASP.NET Core; SDK includes the runtimes)
    dotnet-sdk_8

    # Cloud tools
    awscli2                    # AWS CLI v2

    # Graphics & shader tooling
    renderdoc                  # Frame debugger/profiler (Vulkan/OpenGL/GLES)
    vulkan-tools               # vulkaninfo, vkcube -- enumerate ICDs/devices, smoke-test rendering
    vulkan-tools-lunarg        # vkconfig -- toggle Vulkan layers and settings
    vulkan-validation-layers   # VK_LAYER_KHRONOS_validation -- catch API misuse at runtime
    vulkan-extension-layer     # Emulate optional Vulkan extensions for testing
    spirv-tools                # spirv-as/dis/val/opt/link -- assemble, validate, optimize SPIR-V
    spirv-cross                # Translate SPIR-V back to GLSL/HLSL/MSL, plus reflection
    glslang                    # glslangValidator -- reference GLSL/HLSL to SPIR-V compiler
    shaderc                    # glslc -- GLSL/HLSL to SPIR-V compiler (Google)
    shader-slang               # slangc -- Khronos Slang shading language compiler
    directx-shader-compiler    # dxc -- HLSL to SPIR-V/DXIL
    nagaTools                  # naga + wgpu-info from wgpu-utils (gfx-rs/wgpu shader translator + adapter probe)

    # Profiling & tracing (CPU, memory, dynamic tracing across C++/Rust/Python)
    perf                       # Linux sampling profiler (foundation)
    flamegraph                 # Brendan Gregg's flame graph scripts
    pprof                      # Cross-language pprof-format profile viewer
    graphviz                   # DOT graph renderer (pprof graphs, general use)
    d2                         # Declarative diagram scripting language (terrastruct)
    hyperfine                  # CLI benchmarking (--export-json)
    samply                     # Modern sampling profiler -> Firefox Profiler
    hotspot                    # GUI for perf data
    tracy                      # Frame profiler -- instrumented CPU+GPU timeline for real-time renderers (tracy-client crate)
    cargo-flamegraph           # `cargo flamegraph` convenience for Rust
    heaptrack                  # Heap profiler for C/C++/Rust (fast, text report)
    valgrind                   # memcheck/massif/callgrind/cachegrind
    py-spy                     # Python sampling profiler, attach-to-running
    memray                     # Python memory profiler (Bloomberg)
    scalene                    # Python CPU+memory+GPU, Python vs native split
    bpftrace                   # eBPF dynamic tracing (JSON output)
    bcc                        # BCC toolkit: offcputime, profile, execsnoop, etc.
    ltrace                     # Library-call tracer (strace's dynamic-symbol counterpart; strace comes from NixOS defaults)
    uftrace                    # Function-graph tracer (C/C++/Rust)
    likwid                     # Zen PMU counters: cache/mem/FLOPS/AVX, topology-aware
    hwloc                      # Hardware topology (lstopo, hwloc-bind, hwloc-info)
    config.boot.kernelPackages.cpupower   # CPU frequency/governor control (kernel-matched)
  ] ++ lib.optionals (host.amduprof or false) [
    amduprof                   # AMD uProf CLI (Zen microarch + IBS + timechart)
    amduprof-pcm               # AMD uProf per-core memory/cache counters
  ] ++ lib.optionals (host.nsightGraphics or false) [
    ngfx                       # NVIDIA Nsight Graphics CLI (frame capture, GPU Trace)
    ngfx-capture               # Capture a frame from a target app (headless)
    ngfx-replay                # Replay a captured frame (headless)
  ] ++ [

    # AI coding tools (claude-code and codex install natively via
    # scripts/install-ai-tools.sh; they update too often for OS rebuilds)
    glow
    bubblewrap                 # sandbox runtime for the native claude-code install

    # LSP servers (for neovim)
    bash-language-server
    typescript-language-server
    cmake-language-server
    basedpyright               # Python LSP (pyright fork with better type inference)
    nixd                       # Nix LSP (eval-based completions, option lookups)

    # Formatters & linters (for neovim via conform.nvim)
    stylua                     # Lua
    rustfmt                    # Rust
    gotools                    # Go (goimports)
    prettier                   # TypeScript/JavaScript
    ormolu                     # Haskell
    hlint                      # Haskell linter
    codespell                  # Spell checker for code
    pre-commit                 # Git pre-commit hook framework

    # Desktop apps
    braveAutoscroll vscode vlcScaled telegram-desktop yt-dlp qbittorrentClean obsidian
    yandex-music               # Official Yandex Music app, repackaged for Linux
    mangohud                   # Real-time FPS/GPU/CPU overlay for games
    piper                      # GUI for the G300s: buttons, DPI, polling rate, LED (via ratbagd)

    # VPN
    ookla-speedtest            # `speedtest`: Ookla speed test CLI (compare VPNs)
    wireguard-tools            # WireGuard CLI (kernel module built-in; NM handles GUI)
    openvpn                    # OpenVPN tunnel client
    networkmanager-openvpn     # OpenVPN plugin for NetworkManager GUI
    v2ray                      # Proxy platform for bypassing network restrictions
    v2raynScaled               # v2rayN: GUI client for VLESS/VMess/Trojan/... proxy servers
    xray sing-box              # Proxy cores v2rayN drives
    # ivpn CLI + ivpn-service daemon come from services.ivpn.enable above
    ivpn-ui                    # IVPN desktop GUI

    # Qt Wayland -- needed for native Wayland rendering in Qt apps (Dolphin, KDE tools)
    qt5.qtwayland qt6.qtwayland

    # Hyprland ecosystem
    wayle                      # Status bar / desktop shell (replaced archived hyprpanel)
    rofi                       # App launcher + window switcher
    hyprpaper                  # Wallpaper daemon
    hyprland-per-window-layout # Remembers the keyboard layout per window (us/ru)
    hyprlock                   # Lock screen
    hypridle                   # Idle management (triggers lock/suspend)
    wl-clipboard               # Wayland clipboard (wl-copy/wl-paste)
    socat                      # Unix socket relay (Hyprland event-socket debugging)
    grimblast                  # Screenshot helper (wraps grim+slurp+wl-copy)
    flameshot                  # Screenshot with annotation UI -- bound to Print (wlroots capture via grim is on by default)
    grim                       # Screenshot capture
    slurp                      # Region selection for screenshots
    gpu-screen-recorder-gtk    # GUI for gpu-screen-recorder -- window/screen capture with desktop/mic audio

    # Theming (GTK theme + icons managed by home-manager in theming.nix)

    # Desktop utilities
    nomacsTuned                # Image viewer (IrfanView-like), default for images
    file-roller                # Archive manager GUI (zip/tar/7z)
    hyprsunset                 # Night light (toggled by clicking the bar weather; config/hypr/nightlight.sh)
    vcgtLoader                 # Monitor calibration curve without Hyprland's ICC (nixos/pkgs/vcgt-loader)
    mission-center             # System monitor (CPU/GPU/RAM/disk, GTK4 Wayland native)

    # Desktop services
    lxqt.lxqt-policykit       # Polkit authentication agent (GUI sudo prompts)
    libnotify                  # Desktop notifications (notify-send)
    networkmanagerapplet       # Network manager tray icon
    pavucontrol                # PulseAudio/PipeWire volume control GUI
    brightnessctl              # Screen brightness control
    playerctl                  # MPRIS media player control (play/pause/next)
    seahorse                   # GUI for managing gnome-keyring passwords
    wdisplays                  # Wayland display/monitor configuration GUI
  ] ++ (map lib.getDev (mathLibs ++ desktopRuntimeLibs));

  # Math libs go on CPATH + LIBRARY_PATH + pkg-config so raw `gcc -lblas` works.
  # Desktop-runtime libs are pkg-config only -- their typical consumers
  # (CMake, meson) resolve them via pkg-config rather than -I/-l flags.
  # Trade-off: these env vars leak into unrelated user-session compilations;
  # switch to a shell.nix per project if that causes surprises.
  environment.variables = {
    CC = "clang";
    CXX = "clang++";
    CPATH = lib.makeSearchPathOutput "dev" "include" mathLibs;
    LIBRARY_PATH = lib.makeLibraryPath mathLibs;
    PKG_CONFIG_PATH = lib.concatStringsSep ":" [
      (lib.makeSearchPathOutput "dev" "lib/pkgconfig" (mathLibs ++ desktopRuntimeLibs))
      (lib.makeSearchPathOutput "dev" "share/pkgconfig" (mathLibs ++ desktopRuntimeLibs))
    ];

    # sccache: route CMake-driven C/C++/CUDA through the cache by default.
    # Rust is intentionally NOT wrapped -- sccache disables Cargo incremental
    # compilation, which usually hurts iterative dev cycles more than caching helps.
    # Raw make/autotools projects are not covered (would need CC="sccache clang",
    # which breaks some configure scripts) -- opt in per-project when needed.
    CMAKE_C_COMPILER_LAUNCHER = "sccache";
    CMAKE_CXX_COMPILER_LAUNCHER = "sccache";
    CMAKE_CUDA_COMPILER_LAUNCHER = "sccache";
    SCCACHE_CACHE_SIZE = "50G";
  };

  # Keep the uProf/Nsight downloads in the system closure so the weekly
  # garbage collection never deletes them -- Nix can't re-download them,
  # and every nixpkgs bump rebuilds these packages from the originals.
  system.extraDependencies =
    lib.optionals (host.amduprof or false) [ pkgs.amduprof-unwrapped.src ]
    ++ lib.optionals (host.nsightGraphics or false) [ pkgs.nsight-graphics-unwrapped.src ];
}
