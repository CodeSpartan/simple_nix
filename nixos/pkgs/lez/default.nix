# lez -- an eza fork (modern `ls`) with extras such as `lez --code` (lines of
# code per language). Not in nixpkgs. Upstream's flake pulls in a dozen
# inputs (naersk, rust-overlay, pre-commit...), so this builds the release
# tag with nixpkgs' Rust instead, mirroring upstream's nix/lez.nix.
# Bump: new version + `hash = ""`, build, copy the hashes from the errors.
{ lib, rustPlatform, fetchFromGitHub, cmake, pkg-config, pandoc, installShellFiles, zlib, libgit2 }:

rustPlatform.buildRustPackage rec {
  pname = "lez";
  version = "0.29.1";

  src = fetchFromGitHub {
    owner = "fxrdhan";
    repo = "lez";
    rev = "v${version}";
    hash = "sha256-MJdrmMf67b33Vpua2GdLUH1dJtHqgVN8wlF65r2OF0c=";
  };

  cargoHash = "sha256-budi0FK6ExY1GAf1ItH3ofa5R6zMAugwtjoOvIV1RN8=";

  nativeBuildInputs = [ cmake pkg-config pandoc installShellFiles ];
  buildInputs = [ zlib libgit2 ];  # nixpkgs makes libgit2-sys link the system libgit2

  # Upstream's suite needs git/chattr/locale fixtures; it runs in their CI.
  doCheck = false;

  postInstall = ''
    for page in lez.1 lez_colors.5 lez_colors-explanation.5; do
      sed "s/\$version/${version}/g" "man/$page.md" |
        pandoc --standalone -f markdown -t man >"man/$page"
    done
    installManPage man/lez.1 man/lez_colors.5 man/lez_colors-explanation.5
    installShellCompletion \
      --bash completions/bash/lez \
      --fish completions/fish/lez.fish \
      --zsh completions/zsh/_lez
  '';

  meta = {
    description = "Modern ls replacement (eza fork) with lines-of-code counting";
    homepage = "https://github.com/fxrdhan/lez";
    license = lib.licenses.eupl12;
    mainProgram = "lez";
  };
}
