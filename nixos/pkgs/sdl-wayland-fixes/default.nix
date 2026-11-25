# LD_PRELOAD shim with two SDL3-on-Hyprland workarounds for Unreal: empty
# confirmation dialogs, and a pointer left locked under context menus.
# Details in the .c file.
{ stdenv }:

stdenv.mkDerivation {
  pname = "sdl-wayland-fixes";
  version = "1.0";
  src = ./.;
  buildPhase = ''
    $CC -O2 -fPIC -shared -Wall -Werror -o libsdl-wayland-fixes.so sdl-wayland-fixes.c -ldl -lpthread
  '';
  installPhase = "install -Dm755 libsdl-wayland-fixes.so $out/lib/libsdl-wayland-fixes.so";
}
