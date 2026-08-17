{
  lib,
  copyDesktopItems,
  fetchFromGitHub,
  fftw,
  glib,
  gtk4-layer-shell,
  gtksourceview5,
  installShellFiles,
  libpulseaudio,
  libxkbcommon,
  makeDesktopItem,
  pipewire,
  pixman,
  pkg-config,
  rustPlatform,
  stdenv,
  udev,
  wrapGAppsHook4,
}:
# Adapted from nixpkgs' pkgs/by-name/wa/wayle/package.nix (wayle 0.7.0),
# but built from wayle-rs/wayle PR #255 (adityapandeydev:fix/fractional-scale-dropdowns)
# instead of the v0.7.0 release tag, to test the fractional-scaling dropdown fix
# before it's merged upstream.
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "wayle";
  version = "0.7.0-pr255";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "adityapandeydev";
    repo = "wayle";
    rev = "84f290a63b2e084d266344f4cc8d4fdd59a6b872";
    hash = "sha256-VgRCDxARsEGYFgCWrxlr8cpNihmuzjGL2R95sHdF4wA=";
  };

  cargoHash = "sha256-4PUXJwUP5h/ggZQbY78BdqMh5oZes1XCeWuT2/S94Z4=";

  nativeBuildInputs = [
    copyDesktopItems
    glib
    installShellFiles
    pkg-config
    rustPlatform.bindgenHook
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4-layer-shell.dev
    gtksourceview5
    libxkbcommon.dev
    pixman
    udev

    fftw.dev
    libpulseaudio
    pipewire.dev
  ];

  # Two unrelated pre-existing bugs in this branch, patched just to get the
  # app running at all (neither is related to PR #255's actual fix):
  #
  # 1. crates/wayle-shell's i18n loader panics on startup looking for
  #    locales/en-US/wayle-shell.ftl, which doesn't exist here -- only
  #    underscore-prefixed partials do (_bar.ftl, _dashboard.ftl, etc).
  #    Assemble the missing file from those partials so the app can boot.
  #    (Tried removing the .gitignore, which also happens to blanket-ignore
  #    that filename, thinking rust-embed's folder scan respected it -- it
  #    didn't turn out to matter, since fetchFromGitHub strips .git and
  #    rust-embed's ignore-crate walker requires an actual .git dir to
  #    apply .gitignore rules at all. Left the removal in anyway, harmless.)
  #
  # 2. rust-embed only truly compiles files into the binary in *release*
  #    mode (cfg(not(debug_assertions))); in a debug build it instead reads
  #    them from disk *at runtime*, from the original build-sandbox path --
  #    which is long gone by the time the installed binary actually runs.
  #    That's why an earlier attempt at buildType = "debug" (to dodge the
  #    OOM below) hit the exact same "file not found" panic even after (1)
  #    was fixed: the fix was never even being read. So this has to stay a
  #    release build for the embed to work at all -- instead, fix the OOM
  #    at its actual source (see below) rather than side-stepping release
  #    mode entirely.
  postPatch = ''
    sed -i '/^wayle-shell\.ftl$/d' .gitignore

    cat crates/wayle-shell/locales/en-US/*.ftl \
        crates/wayle-shell/locales/en-US/dropdowns/*.ftl \
        > crates/wayle-shell/locales/en-US/wayle-shell.ftl

    # This machine only has 7.5GB RAM. The workspace's release profile
    # enables LTO + codegen-units=1, which OOM-killed rustc on the final
    # wayle-shell crate (same failure mode as the `br` overlay package --
    # see CLAUDE.md). Turn both off so release compilation stays within a
    # normal per-crate memory footprint instead of one giant LTO unit.
    sed -i \
      -e 's/^lto = true$/lto = false/' \
      -e 's/^codegen-units = 1$/codegen-units = 16/' \
      Cargo.toml
  '';

  cargoBuildFlags = [
    "--bin=wayle"
    "--bin=wayle-settings"
  ];

  doCheck = false;

  preInstall = ''
    mkdir -p "$out/share/icons/hicolor/scalable/apps"
    cp -r resources/icons "$out/share"
    cp resources/wayle-settings.svg "$out/share/icons/hicolor/scalable/apps"
  '';

  postInstall =
    lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform)
      ''
        installShellCompletion --cmd wayle \
          --bash <($out/bin/wayle completions bash) \
          --fish <($out/bin/wayle completions fish) \
          --zsh <($out/bin/wayle completions zsh)
      '';

  preFixup = ''
    gappsWrapperArgs+=( --suffix PATH : $out/bin )
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "com.wayle.settings.desktop";
      type = "Application";
      desktopName = "Wayle Settings";
      genericName = "Shell Settings";
      comment = "Configure the Wayle desktop shell";
      exec = "wayle-settings";
      icon = "wayle-settings";
      terminal = false;
      categories = [ "Settings" "DesktopSettings" "GTK" ];
      keywords = [ "wayle" "settings" "shell" "bar" "wayland" "config" ];
      startupNotify = true;
      startupWMClass = "com.wayle.settings";
    })
  ];

  meta = {
    description = "Wayle, built from PR #255 (fractional-scale dropdown fix)";
    homepage = "https://github.com/wayle-rs/wayle/pull/255";
    license = lib.licenses.mit;
    mainProgram = "wayle";
    platforms = lib.platforms.linux;
  };
})
