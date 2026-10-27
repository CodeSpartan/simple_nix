# English dates in the Wayle bar (clock shows "Tue Oct 27", not "Вт окт 27")
# without touching the system locale: host.nix sets LC_TIME to ru_RU for
# everything else on purpose.
#
# Wayle's clock has no language option -- it follows LC_TIME. Setting it in
# Hyprland's launch line isn't enough: `wayle panel restart` starts the new
# bar from whatever terminal ran it. Wrapping the `wayle` binary covers every
# way it starts. A thin wrapper, so nothing is recompiled.
#
# Must come after wayle-pr255.nix in nixpkgs.overlays.
final: prev:

{
  wayle = prev.symlinkJoin {
    name = "wayle-${prev.wayle.version}-en-dates";
    inherit (prev.wayle) version meta;
    paths = [ prev.wayle ];
    nativeBuildInputs = [ prev.makeWrapper ];
    # bin/.wayle-wrapped already exists (GApps wrapper), so wrapProgram would
    # clobber it -- replace just the bin/wayle symlink with a new wrapper.
    postBuild = ''
      rm "$out/bin/wayle"
      makeWrapper "${prev.wayle}/bin/wayle" "$out/bin/wayle" --set LC_TIME en_US.UTF-8
    '';
  };
}
