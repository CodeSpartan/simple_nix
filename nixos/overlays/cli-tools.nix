# Overlay for CLI tools not usable straight from nixpkgs.
# claude-code and codex are intentionally NOT packaged here: they release
# too often to justify an OS rebuild per bump. They install natively to
# ~/.local/bin via scripts/install-ai-tools.sh instead.
{ fenix }:
final: prev:

let
  # -- br / beads_rust (buildRustPackage, GitHub source) ---------------
  # Upstream's flake.nix is broken (crane vendors Cargo.lock at the wrong
  # path) and pulls a sibling toon_rust input. We sidestep that by building
  # the published tarball directly: the released Cargo.toml depends on
  # `tru` from crates.io, not a path dep, so no source-tree gymnastics.
  # Nightly is required because the transitive crate `fsqlite-types` opts
  # into #![feature(portable_simd)]. Pinned to upstream's rust-toolchain.toml.
  brVersion = "0.2.11";
  brSrcHash = "sha256-XfxO1gDt51CWv6T/wEX97uLm89Px0rEmCZEcofeWZG0=";
  brCargoHash = "sha256-3u7GMriV2ZG0mjjGYLXGcUDQrs83uRYDMy5NKXTdaTI=";
  brNightlyDate = "2026-02-19";
  brNightlySha = "sha256-ccIyMJknpRkaU9pLkFC4E9j0XxMa50GT4CYhwGvs8/U=";

in {

  # -- br --------------------------------------------------------------
  br = let
    fenixPkgs = fenix.packages.${prev.stdenv.hostPlatform.system};
    nightly = fenixPkgs.toolchainOf {
      channel = "nightly";
      date = brNightlyDate;
      sha256 = brNightlySha;
    };
    rustToolchain = fenixPkgs.combine [
      nightly.cargo
      nightly.rustc
      nightly.rust-src
    ];
    rustPlatform = prev.makeRustPlatform {
      cargo = rustToolchain;
      rustc = rustToolchain;
    };
  in rustPlatform.buildRustPackage {
    pname = "br";
    version = brVersion;

    src = prev.fetchFromGitHub {
      owner = "Dicklesworthstone";
      repo = "beads_rust";
      tag = "v${brVersion}";
      hash = brSrcHash;
    };

    cargoHash = brCargoHash;

    nativeBuildInputs = [ prev.pkg-config ];
    buildInputs = [ prev.openssl prev.sqlite ];

    env.OPENSSL_NO_VENDOR = "1";

    doCheck = false;

    meta = {
      description = "Agent-first issue tracker (SQLite + JSONL). Rust port of beads.";
      homepage = "https://github.com/Dicklesworthstone/beads_rust";
      license = prev.lib.licenses.mit;
      mainProgram = "br";
      platforms = prev.lib.platforms.unix;
    };
  };
}
