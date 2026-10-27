# Loads an ICC profile's calibration curve (vcgt) into the display gamma table
# via wlr-gamma-control -- Hyprland's own ICC support crushes near-black.
{ stdenv, wayland, wayland-scanner, wlr-protocols }:

stdenv.mkDerivation {
  pname = "vcgt-loader";
  version = "1.0";
  src = ./.;
  strictDeps = true;
  nativeBuildInputs = [ wayland-scanner ];
  buildInputs = [ wayland ];
  buildPhase = ''
    xml=${wlr-protocols}/share/wlr-protocols/unstable/wlr-gamma-control-unstable-v1.xml
    wayland-scanner client-header $xml wlr-gamma-control-unstable-v1-client-protocol.h
    wayland-scanner private-code  $xml wlr-gamma-control-unstable-v1-protocol.c
    $CC -O2 -Wall -o vcgt-loader vcgt-loader.c wlr-gamma-control-unstable-v1-protocol.c -lwayland-client -lm
  '';
  installPhase = "install -Dm755 vcgt-loader $out/bin/vcgt-loader";
  meta.mainProgram = "vcgt-loader";
}
