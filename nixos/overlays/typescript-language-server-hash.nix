# TEMPORARY: nixpkgs shipped typescript-language-server 6.0.2 with a wrong
# pnpmDeps hash (fetch fails with "hash mismatch in fixed-output derivation").
# Fixed upstream in NixOS/nixpkgs#572951 (merged to master 2026-10-11).
#
# Delete this file and its entry in configuration.nix once nixos-unstable
# includes that fix. To check: delete them and rebuild. If it builds, the
# workaround is no longer needed.
final: prev: {
  typescript-language-server = prev.typescript-language-server.overrideAttrs (old: {
    pnpmDeps = old.pnpmDeps.overrideAttrs {
      outputHash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=";
    };
  });
}
