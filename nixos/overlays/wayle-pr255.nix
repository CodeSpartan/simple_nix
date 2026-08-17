# TEMPORARY: wayle's dashboard/notification-bell dropdowns render at 0x0 and
# instantly close on this laptop's 1080p @ 1.5x scale -- an upstream bug
# (https://github.com/wayle-rs/wayle/issues/242, first reported as #113).
# The dropdown's requested content height doesn't fit the logical screen
# height left after scaling, and older wayle mishandles that overflow by
# collapsing to zero instead of clamping/scrolling. Fixed upstream by PR
# #255 (https://github.com/wayle-rs/wayle/pull/255), unmerged as of
# 2026-08-17. This overlay builds wayle from that PR's branch instead of
# the v0.7.0 release tag nixpkgs currently ships.
#
# See wayle-pr255-package.nix for the two unrelated bugs that had to be
# patched around just to get that branch running at all.
#
# TODO: once PR #255 merges and ships in a nixpkgs release, delete this
# overlay + wayle-pr255-package.nix, and drop it from configuration.nix's
# nixpkgs.overlays list. Back to the plain `wayle` package at that point.
final: prev:

{
  wayle = final.callPackage ./wayle-pr255-package.nix { };
}
