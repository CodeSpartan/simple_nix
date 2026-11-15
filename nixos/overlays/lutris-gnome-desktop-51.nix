# Lutris 0.5.22 crashes at startup with gnome-desktop 51 ("'GnomeDesktop'
# object has no attribute 'RRScreen'"): that version's GnomeDesktop 3.0 has
# no RRScreen, and Lutris only catches GLib.Error around it. Catch the
# AttributeError too, so it falls back to its xrandr display manager.
# Drop once nixpkgs' Lutris starts without it.
final: prev: {
  lutris-unwrapped = prev.lutris-unwrapped.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace lutris/util/display.py \
        --replace-fail "except GLib.Error:" "except (GLib.Error, AttributeError):"
    '';
  });
}
