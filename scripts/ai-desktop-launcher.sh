#!/usr/bin/env bash
set -euo pipefail

# Installed by install-ai-tools.sh beside the locally extracted app releases.
tool="${1:?Missing desktop app name}"
shift
app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
case "$tool" in
  chatgpt) app_dir="$app_root/current/usr/lib/chatgpt"; executable=ChatGPT ;;
  claude-desktop) app_dir="$app_root/current/usr/lib/claude-desktop"; executable=claude-desktop ;;
  *) echo "Unknown desktop app: $tool" >&2; exit 2 ;;
esac

flags=()
if [[ -e /etc/NIXOS ]]; then
  # nix-ld supplies the loader. Reuse libraries from the installed browser and
  # keyring manager instead of packaging the apps in Nix or hardcoding store paths.
  # Resolve on each launch so a rebuild/garbage collection cannot stale the paths.
  runtime_roots=()
  for runtime in brave seahorse; do
    if ! runtime_bin=$(command -v "$runtime"); then
      echo "ERROR: $runtime must be installed to supply NixOS desktop libraries" >&2
      exit 1
    fi
    runtime_roots+=("$(readlink -f "$runtime_bin")")
  done
  closure=$(nix-store --query --requisites "${runtime_roots[@]}")
  libraries="$app_dir"
  schema_paths=""
  while IFS= read -r store_path; do
    for directory in "$store_path/lib" "$store_path/lib64"; do
      [[ ! -d "$directory" ]] || libraries+=":$directory"
    done
    for directory in "$store_path"/share/gsettings-schemas/*; do
      [[ ! -d "$directory" ]] || schema_paths+="$directory:"
    done
  done <<< "$closure"
  export LD_LIBRARY_PATH="$libraries${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export NIX_LD_LIBRARY_PATH="$LD_LIBRARY_PATH${NIX_LD_LIBRARY_PATH:+:$NIX_LD_LIBRARY_PATH}"
  export XDG_DATA_DIRS="$schema_paths${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

  # Hyprland is not one of Chromium's auto-detected keyring desktops. Select
  # the GNOME Secret Service already configured by security.nix explicitly.
  flags+=(--password-store=gnome-libsecret)
  # Match the session's native display instead of depending on XWayland.
  if [[ -n "${WAYLAND_DISPLAY:-}" && "${NIXOS_OZONE_WL:-}" == 1 ]]; then
    flags+=(--ozone-platform=wayland)
  fi
fi

# Chromium needs writable temporary files even when /tmp's tmpfs is full.
# Keep this app's temporary files private and on the home filesystem.
if [[ -z "${TMPDIR:-}" || "$TMPDIR" == /tmp ]]; then
  TMPDIR="${XDG_CACHE_HOME:-$HOME/.cache}/ai-tools/$tool/tmp"
  (umask 077; mkdir -p "$TMPDIR")
  export TMPDIR
fi

exec "$app_dir/$executable" "${flags[@]}" "$@"
