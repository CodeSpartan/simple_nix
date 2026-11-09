# PhotoCraft (github.com/storytold/photocraft): Photoshop-like editor in Rust.
# Not in nixpkgs/Flathub, so this wraps the official prebuilt Linux tarball.
# The binaries only link libc; the GPU/window libraries (Vulkan, Wayland,
# X11, xkbcommon, dbus) are dlopen'd at runtime, hence the LD_LIBRARY_PATH.
# Bump: new version + hash (`nix-prefetch-url <tar.gz url>`, or the hash
# from the release's SHA256SUMS.txt via `nix hash convert`).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  dbus,
  libGL,
  libX11,
  libXcursor,
  libXi,
  libxcb,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

let
  runtimeLibs = [
    dbus
    libGL
    libX11
    libXcursor
    libXi
    libxcb
    libxkbcommon
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation rec {
  pname = "photocraft";
  version = "0.21.0";

  src = fetchurl {
    url = "https://github.com/storytold/photocraft/releases/download/v${version}/photocraft-${version}-linux-x86_64.tar.gz";
    sha256 = "3115e56cc646dbad3541e39b6323b8a24318fee6194d784ddf6d065f7b5d2d37";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin share $out/
    for b in photocraft photocraft-cli; do
      wrapProgram $out/bin/$b \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
    done
    runHook postInstall
  '';

  meta = {
    description = "Layered image editor with PSD support, written in Rust";
    homepage = "https://github.com/storytold/photocraft";
    license = with lib.licenses; [ mit asl20 ];
    mainProgram = "photocraft";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
