# Tray icon for the MAX messenger with a red dot for unread messages.
# See max-tray.py.
{ stdenvNoCC, makeWrapper, python3, glib, hyprland, flatpak }:

stdenvNoCC.mkDerivation {
  pname = "max-tray";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    install -Dm644 max-tray.py $out/share/max-tray/max-tray.py
    install -Dm644 -t $out/share/max-tray/icons max.svg max-unread.svg
    makeWrapper ${python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3 $out/bin/max-tray \
      --add-flags $out/share/max-tray/max-tray.py \
      --set MAX_TRAY_ICONS $out/share/max-tray/icons \
      --prefix GI_TYPELIB_PATH : ${glib.out}/lib/girepository-1.0 \
      --prefix PATH : ${hyprland}/bin:${flatpak}/bin
  '';
  meta.mainProgram = "max-tray";
}
