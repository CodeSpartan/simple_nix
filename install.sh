#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"

echo "==> Generating hardware config..."
# Write to temp file first to avoid truncating the existing config on failure
_hw_tmp=$(mktemp)
_install_ok=false
trap 'rm -f "$_hw_tmp"; $_install_ok || git -C "$REPO" reset nixos/hardware-configuration.nix 2>/dev/null || true' EXIT
sudo nixos-generate-config --show-hardware-config > "$_hw_tmp"
mv "$_hw_tmp" "$REPO/nixos/hardware-configuration.nix"
# Nix flakes in git repos only see tracked files; stage it temporarily so nixos-rebuild can find it
git -C "$REPO" add -f nixos/hardware-configuration.nix

echo "==> Rebuilding NixOS..."
_hostname=$(nix eval --raw -f "$REPO/nixos/host.nix" hostname 2>/dev/null || hostname)
_switch_failed=false
_before_system=$(readlink -f /run/current-system)
if ! sudo nixos-rebuild switch -L --flake "$REPO/nixos#$_hostname"; then
  # A non-zero exit here doesn't always mean the build/eval failed --
  # switch-to-configuration also exits non-zero if ANY unrelated unit fails
  # to (re)start (e.g. fwupd-refresh.service), even once the generation
  # itself activated fine. Only treat that specific case as non-fatal: check
  # /run/current-system actually moved to a new generation. If it didn't,
  # this was a real build/activation failure -- stop exactly as before.
  _after_system=$(readlink -f /run/current-system)
  if [[ "$_after_system" != "$_before_system" ]]; then
    _switch_failed=true
    echo "==> WARNING: nixos-rebuild switch exited non-zero, but the system" >&2
    echo "    DID switch to the new generation -- likely an unrelated unit" >&2
    echo "    failed to (re)start (check: systemctl --failed)." >&2
    echo "    Continuing to symlink configs regardless." >&2
  else
    echo "==> nixos-rebuild switch failed and the system did not activate." >&2
    exit 1
  fi
fi

# Ensure new packages are in PATH for the current session
export PATH="/run/current-system/sw/bin:$PATH"

echo "==> Symlinking configs..."
"$REPO/link.sh"

# Unstage hardware-configuration.nix so it stays gitignored
git -C "$REPO" reset nixos/hardware-configuration.nix 2>/dev/null || true

_install_ok=true

if $_switch_failed; then
  echo "==> Done, but nixos-rebuild switch reported a failure -- see warning above." >&2
  exit 1
fi
