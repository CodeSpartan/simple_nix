# Epic Games Launcher (Linux Preview), from Epic's official .deb -- Epic
# stopped offering the AppImage. A Tauri app (WebKitGTK). The download link
# (launcher.epicgames.com) is unversioned; it redirects to the versioned URL
# used here. To update: open that redirect, take the new version from it,
# and replace version + hash (`nix-prefetch-url <url>`, or build once and
# copy the hash from the error).
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  webkitgtk_4_1,
  gtk3,
  libsoup_3,
  glib,
  cairo,
  gdk-pixbuf,
  libX11,
  dbus,
  libayatana-appindicator,
  glib-networking,
}:

stdenv.mkDerivation rec {
  pname = "epic-games-launcher";
  version = "0.114.0+g04485d6";

  src = fetchurl {
    url = "https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/${lib.escapeURL version}/Linux/EpicGamesLauncher-x86_64.deb";
    hash = "sha256-C9Pj7CdsGvXIZwMlxXtwKSkPtIEd4Hhb/jYqMWE/lsc=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook wrapGAppsHook3 ];
  buildInputs = [
    webkitgtk_4_1 gtk3 libsoup_3 glib cairo gdk-pixbuf libX11 dbus
    glib-networking   # TLS for WebKit (else "TLS support is not available")
    stdenv.cc.cc.lib
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r usr/* $out/
    runHook postInstall
  '';

  # libEOSSDK sits next to the binary's install dir, not on its rpath.
  appendRunpaths = [ "${placeholder "out"}/lib/epic-games-launcher" ];
  # Tray icon: Tauri loads libayatana-appindicator at runtime (dlopen).
  # WebKitGTK's DMA-BUF renderer crashes on NVIDIA under Wayland a second
  # after start ("Error 71 (Protocol error) dispatching to Wayland display").
  # Its compositing mode blanks the page after a few seconds (only a few
  # elements keep redrawing).
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
      --set-default WEBKIT_DISABLE_COMPOSITING_MODE 1
    )
  '';

  meta = {
    description = "Epic Games Launcher (Linux Preview)";
    mainProgram = "EpicGamesLauncher";
    homepage = "https://store.epicgames.com/news/epic-games-launcher-preview";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
