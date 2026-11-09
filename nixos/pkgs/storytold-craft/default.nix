# Storyteller's "Craft" apps (github.com/storytold): PhotoCraft (Photoshop-
# like), PdfCraft (PDF reader/editor), WordCraft (Word-like). All Rust, not
# in nixpkgs/Flathub, all released the same way -- this wraps the official
# prebuilt Linux tarball. The binaries only link libc; the GPU/window
# libraries (Vulkan, GL, Wayland, X11, xkbcommon, dbus) are dlopen'd at
# runtime, hence the LD_LIBRARY_PATH.
# Bump: in programs.nix, new version + sha256 from the release's
# SHA256SUMS.txt (line for <name>-<version>-linux-x86_64.tar.gz).
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
  libXrender,
  libxcb,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:

{ pname, version, sha256, description, wrapperArgs ? [ ] }:

let
  runtimeLibs = [
    dbus
    libGL
    libX11
    libXcursor
    libXi
    libXrender
    libxcb
    libxkbcommon
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.tar.gz";
    inherit sha256;
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin share $out/
    for b in $out/bin/*; do
      wrapProgram $b --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
        ${lib.escapeShellArgs wrapperArgs}
    done
    runHook postInstall
  '';

  meta = {
    inherit description;
    homepage = "https://github.com/storytold/${pname}";
    license = with lib.licenses; [ mit asl20 ];
    mainProgram = pname;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
