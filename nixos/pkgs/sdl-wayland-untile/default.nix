# LD_PRELOAD shim that hides Hyprland's "tiled" states from SDL3 apps, so
# fixed-size SDL windows keep their size (Unreal's dialogs collapsed to an
# empty 1x1 frame). Details in the .c file.
{ stdenv }:

stdenv.mkDerivation {
  pname = "sdl-wayland-untile";
  version = "1.0";
  src = ./.;
  buildPhase = ''
    $CC -O2 -fPIC -shared -Wall -Werror -o libsdl-wayland-untile.so sdl-wayland-untile.c -ldl -lpthread
  '';
  installPhase = "install -Dm755 libsdl-wayland-untile.so $out/lib/libsdl-wayland-untile.so";
}
