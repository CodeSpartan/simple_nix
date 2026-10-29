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

# uProf/Nsight installers sit behind vendor logins, so Nix can't download them.
# Re-add every file from host.nix's vendorDir (no-op if already in the store);
# this covers a fresh install. Missing folder (e.g. D: not mounted) is skipped.
_vendor_dir=$(nix eval --raw -f "$REPO/nixos/host.nix" vendorDir 2>/dev/null || true)
if [[ -n "$_vendor_dir" && -d "$_vendor_dir" ]]; then
  echo "==> Adding vendor installers from $_vendor_dir to the Nix store..."
  for _f in "$_vendor_dir"/*; do
    [[ -f "$_f" ]] && nix store add-file "$_f" >/dev/null
  done
fi

echo "==> Rebuilding NixOS..."
_hostname=$(nix eval --raw -f "$REPO/nixos/host.nix" hostname 2>/dev/null || hostname)
# Exit 4 = new system is active but some unit is in a failed state, even an unrelated
# one like fwupd-refresh without network; clear stale failures, then warn instead of aborting
sudo systemctl reset-failed
_rc=0
sudo nixos-rebuild switch -L --flake "$REPO/nixos#$_hostname" || _rc=$?
if [[ $_rc -eq 4 ]]; then
  echo "    WARNING: switched, but some units failed (listed above); continuing"
elif [[ $_rc -ne 0 ]]; then
  exit "$_rc"
fi

# Ensure new packages are in PATH for the current session; wrappers first so sudo stays setuid
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

echo "==> Symlinking configs..."
"$REPO/link.sh"

echo "==> Installing and updating Flatpak apps..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# Already-installed apps are skipped; the update below covers them
sudo flatpak install --noninteractive flathub \
  com.discordapp.Discord
# Also pulls the GL.nvidia extension matching a new host driver
sudo flatpak update --noninteractive
sudo flatpak uninstall --unused --noninteractive

# Unstage hardware-configuration.nix so it stays gitignored
git -C "$REPO" reset nixos/hardware-configuration.nix 2>/dev/null || true

_install_ok=true
