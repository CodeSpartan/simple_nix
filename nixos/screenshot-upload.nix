# Upload a screenshot to Gyazo or Cloudinary: link to the clipboard + opened
# in Brave. Two ways in:
# - Shift+Print (Gyazo) / Ctrl+Print (Cloudinary) in config/hypr/user.lua:
#   the usual Flameshot screen; Enter uploads.
# - Flameshot's "Open with" button (Ctrl+O) lists "Upload to Gyazo" /
#   "Upload to Cloudinary" (desktop entries below, under Graphics).
# - Dolphin: right-click image(s) -> "Upload to" -> Gyazo / Cloudinary.
# Script and credential paths: pkgs/screenshot-upload/screenshot-upload.sh.
{ pkgs, ... }:

let
  screenshotUpload = pkgs.writeShellApplication {
    name = "screenshot-upload";
    runtimeInputs = with pkgs; [ curl jq wl-clipboard libnotify coreutils gnused util-linux ];
    # Brave comes from the system profile (our wrapped build), not a fixed path.
    text = builtins.readFile ./pkgs/screenshot-upload/screenshot-upload.sh;
  };

  uploadEntry = service: label: pkgs.makeDesktopItem {
    name = "screenshot-upload-${service}";
    desktopName = "Upload to ${label}";
    exec = "screenshot-upload ${service} %f";
    icon = "document-send";
    mimeTypes = [ "image/png" ];
    categories = [ "Graphics" ];
  };

  # Dolphin right-click menu, for any image type and several files at once.
  # Executable: KIO only trusts service menus outside /usr that are.
  dolphinMenu = pkgs.writeTextFile {
    name = "screenshot-upload-servicemenu";
    destination = "/share/kio/servicemenus/screenshot-upload.desktop";
    executable = true;
    text = ''
      [Desktop Entry]
      Type=Service
      MimeType=image/*;
      Actions=gyazo;cloudinary;
      X-KDE-Submenu=Upload to
      X-KDE-Submenu[ru]=Загрузить в
      Icon=document-send

      [Desktop Action gyazo]
      Name=Gyazo
      Icon=document-send
      Exec=screenshot-upload gyazo %F

      [Desktop Action cloudinary]
      Name=Cloudinary
      Icon=document-send
      Exec=screenshot-upload cloudinary %F
    '';
  };
in
{
  environment.systemPackages = [
    screenshotUpload
    (uploadEntry "gyazo" "Gyazo")
    (uploadEntry "cloudinary" "Cloudinary")
    dolphinMenu
  ];
}
