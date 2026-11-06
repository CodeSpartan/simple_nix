# nixpkgs' wowup-cf (pkgs/by-name/wo/wowup-cf) with a newer version: nixpkgs
# has 2.24.0, which only knows the WoW: Forever *beta*; the live `_forever_`
# client needs 2.24.1+. Its recipe binds the version in a `let`, so it can't
# be overridden -- hence this copy. Drop it once nixpkgs has >= 2.25.4.
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  version = "2.25.4";
  pname = "wowup-cf";

  src = fetchurl {
    url = "https://github.com/WowUp/WowUp.CF/releases/download/v${version}/WowUp-CF-${version}.AppImage";
    hash = "sha256-tKOFboaUo1wgLJ2xjLPOyqHrf8Do+oS0ZzL2fcs8Jc4=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  meta = {
    description = "World of Warcraft addon updater with CurseForge support";
    mainProgram = "wowup-cf";
    homepage = "https://wowup.io/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
