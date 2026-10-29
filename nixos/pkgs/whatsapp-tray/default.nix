# Tray icon for the WhatsApp Brave PWA with a red dot for new messages.
# See whatsapp-tray.py.
{ stdenvNoCC, makeWrapper, python3, glib, dbus, hyprland }:

stdenvNoCC.mkDerivation {
  pname = "whatsapp-tray";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    install -Dm644 whatsapp-tray.py $out/share/whatsapp-tray/whatsapp-tray.py
    install -Dm644 -t $out/share/whatsapp-tray/icons whatsapp.svg whatsapp-unread.svg
    makeWrapper ${python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3 $out/bin/whatsapp-tray \
      --add-flags $out/share/whatsapp-tray/whatsapp-tray.py \
      --set WHATSAPP_TRAY_ICONS $out/share/whatsapp-tray/icons \
      --prefix GI_TYPELIB_PATH : ${glib.out}/lib/girepository-1.0 \
      --prefix PATH : ${dbus}/bin:${hyprland}/bin
  '';
  meta.mainProgram = "whatsapp-tray";
}
