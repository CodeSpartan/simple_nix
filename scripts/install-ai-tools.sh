#!/usr/bin/env bash
set -euo pipefail

# Install/update AI CLI tools and official Linux desktop apps into ~/.local.
# These tools release too often to package in nix (an OS rebuild per bump);
# ~/.local/bin is already on PATH via home-manager sessionPath.
#
#   claude  Anthropic's official installer. Self-updates after the first
#           install, so this script only needs to run once.
#   codex   npm package (vendors static musl binaries, runs on NixOS
#           unpatched). npm's default prefix is the read-only nix store,
#           so --prefix ~/.local routes the bin to ~/.local/bin.
#           Rerun this script to update the CLI and managed app-server
#           daemon together. Updating the daemon can interrupt active work.
#
#   chatgpt / claude-desktop: official .deb downloads, extracted locally.
#           Rerun this script to update; no root access or NixOS rebuild.
#
# Usage: install-ai-tools.sh [claude|codex|chatgpt|claude-desktop|cli|gui]
#        No argument installs/updates all four tools.

BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOL_FILTER="${1:-}"

usage() {
  echo "Usage: $0 [claude|codex|chatgpt|claude-desktop|cli|gui]"
  echo "No argument installs/updates both CLIs and both desktop apps."
}

if [[ $# -gt 1 ]]; then usage >&2; exit 2; fi
case "$TOOL_FILTER" in
  -h|--help) usage; exit 0 ;;
  ''|claude|codex|chatgpt|claude-desktop|cli|gui) ;;
  *) usage >&2; exit 2 ;;
esac

should_install() {
  [[ -z "$TOOL_FILTER" || "$TOOL_FILTER" == "$1" || "$TOOL_FILTER" == "${2:-}" ]]
}

install_claude() {
  echo "-- claude-code ----------------------------"
  if [[ -x "${BIN_DIR}/claude" ]]; then
    echo "  installed: $("${BIN_DIR}/claude" --version 2>/dev/null || echo '?')"
    "${BIN_DIR}/claude" update
    echo "  claude updated"
    return
  fi
  curl -fsSL https://claude.ai/install.sh | bash
  echo "  installed: $("${BIN_DIR}/claude" --version 2>/dev/null || echo '?')"
}

install_codex() {
  echo "-- codex ----------------------------------"

  local latest
  latest=$(npm view @openai/codex version 2>/dev/null || true)
  if [[ -z "$latest" ]]; then
    echo "  ERROR: could not fetch latest version from npm"; return 1
  fi

  local current=""
  if [[ -x "${BIN_DIR}/codex" ]]; then
    current=$("${BIN_DIR}/codex" --version 2>/dev/null | grep -o '[0-9.]*[0-9]' | head -1 || true)
  fi
  if [[ "$current" == "$latest" ]]; then
    echo "  up to date: ${current}"
  else
    echo "  installing: ${current:-none} -> ${latest}"
    npm install -g --prefix "${HOME}/.local" "@openai/codex@${latest}"
    echo "  installed: $("${BIN_DIR}/codex" --version 2>/dev/null || echo '?')"
  fi

  # The daemon has a separate package and can lag behind an up-to-date CLI.
  echo "  updating managed app-server from CLI (may interrupt active Codex work)"
  "${BIN_DIR}/codex" app-server daemon update --from-cli --yes
  "${BIN_DIR}/codex" app-server daemon version
}

install_desktop() (
  local tool="$1" repository="$2" executable="$3" architecture
  echo "-- ${tool} desktop ------------------------"
  case "$(uname -sm)" in
    'Linux x86_64') architecture=amd64 ;;
    'Linux aarch64') architecture=arm64 ;;
    *) echo "ERROR: desktop downloads require Linux x86_64 or aarch64" >&2; exit 1 ;;
  esac

  local dependency
  for dependency in curl ar tar sha256sum sort awk flock python3; do
    command -v "$dependency" >/dev/null || {
      echo "ERROR: missing desktop installer dependency: $dependency" >&2; exit 1;
    }
  done
  if [[ -e /etc/NIXOS ]]; then
    # Reuse the Chromium/GTK/keyring libraries already installed by this config.
    for dependency in nix-store brave seahorse; do
      command -v "$dependency" >/dev/null || {
        echo "ERROR: $dependency is required for the NixOS desktop launcher" >&2; exit 1;
      }
    done
  fi

  local app_root="${DATA_DIR}/ai-tools/${tool}" stage
  mkdir -p "$app_root/releases" "$BIN_DIR" "${DATA_DIR}/applications"
  exec 9>"$app_root/.install.lock"
  flock -x 9
  # Packages are large: stage beside the installation, not in the /tmp tmpfs.
  stage=$(mktemp -d "$app_root/.install.XXXXXXXX")
  trap 'rm -rf -- "$stage"' EXIT

  curl -fsSL --retry 3 --connect-timeout 15 \
    "$repository/dists/stable/main/binary-$architecture/Packages" -o "$stage/Packages"
  local metadata version filename checksum
  metadata=$(awk -v wanted="$tool" -v arch="$architecture" '
    BEGIN { RS=""; FS="\n"; OFS="\t" }
    {
      package=version=architecture=filename=checksum=""
      for (i=1; i<=NF; i++) {
        sub(/\r$/, "", $i)
        if ($i ~ /^Package: /) package=substr($i,10)
        if ($i ~ /^Version: /) version=substr($i,10)
        if ($i ~ /^Architecture: /) architecture=substr($i,15)
        if ($i ~ /^Filename: /) filename=substr($i,11)
        if ($i ~ /^SHA256: /) checksum=substr($i,9)
      }
      if (package==wanted && architecture==arch) print version,filename,checksum
    }
  ' "$stage/Packages" | sort -t $'\t' -k1,1V | tail -n 1)
  IFS=$'\t' read -r version filename checksum <<< "$metadata"
  if [[ ! "$version" =~ ^[a-zA-Z0-9.+:~_-]+$ ||
        "$filename" != pool/* || "$filename" == *..* ||
        ! "$checksum" =~ ^[a-fA-F0-9]{64}$ ]]; then
    echo "ERROR: invalid or missing $tool package metadata" >&2; exit 1
  fi

  local release="$app_root/releases/${version}-${checksum:0:12}"
  if [[ -x "$release/$executable" && -f "$release/.complete" ]]; then
    echo "  up to date: $version"
  else
    echo "  downloading: $version (close $tool before updating)"
    curl -fL --retry 3 --connect-timeout 15 \
      "$repository/$filename" -o "$stage/package.deb"
    printf '%s  %s\n' "$checksum" "$stage/package.deb" | sha256sum --check --status
    local payload
    payload=$(ar t "$stage/package.deb" | awk '/^data\.tar(\.(xz|gz|zst|bz2))?$/ { print }')
    if [[ -z "$payload" || "$payload" == *$'\n'* ]]; then
      echo "ERROR: unsupported Debian archive payload" >&2; exit 1
    fi
    # A file lets tar detect compression without requiring dpkg-deb.
    ar p "$stage/package.deb" "$payload" > "$stage/$payload"
    mkdir "$stage/root"
    tar --extract --file "$stage/$payload" --directory "$stage/root" --no-same-owner
    if [[ ! -x "$stage/root/$executable" ]]; then
      echo "ERROR: $tool package is missing $executable" >&2; exit 1
    fi
    touch "$stage/root/.complete"
    # An interrupted extraction never replaces the working installation.
    rm -rf -- "$release"
    mv -- "$stage/root" "$release"
  fi

  # Install the launcher and rewrite the vendor desktop entry's absolute paths.
  install -m755 "$SCRIPT_DIR/ai-desktop-launcher.sh" "$stage/launcher"
  mv -f -- "$stage/launcher" "$app_root/launcher"
  printf '#!/usr/bin/env bash\nexec %q %q "$@"\n' "$app_root/launcher" "$tool" > "$stage/bin"
  install -m755 "$stage/bin" "$BIN_DIR/$tool"
  local desktop
  for desktop in "$release"/usr/share/applications/*.desktop; do
    [[ -f "$desktop" ]] || continue
    python3 - "$desktop" "$BIN_DIR/$tool" "$release" "$stage/desktop" <<'PY'
import pathlib
import re
import sys

source, launcher, release, destination = sys.argv[1:]
# Desktop Exec has its own escaping rules (including literal % field codes).
escaped = launcher.replace("\\", "\\\\").replace("%", "%%")
escaped = re.sub(r'(["`$])', r'\\\1', escaped)
escaped = escaped.replace("\\", "\\\\")
text = pathlib.Path(source).read_text()
text = re.sub(r'^Exec=(?:"[^"]*"|\S+)', lambda _: f'Exec="{escaped}"', text, flags=re.M)
text = re.sub(r'^TryExec=.*$', lambda _: f'TryExec={launcher}', text, flags=re.M)
text = re.sub(r'^(Icon|Path)=/usr/', lambda m: f'{m[1]}={release}/usr/', text, flags=re.M)
pathlib.Path(destination).write_text(text)
PY
    install -m644 "$stage/desktop" "${DATA_DIR}/applications/${desktop##*/}"
  done
  if [[ -d "$release/usr/share/icons" ]]; then
    mkdir -p "${DATA_DIR}/icons"
    cp -r "$release/usr/share/icons/." "${DATA_DIR}/icons/"
  fi
  # Keep the former release for rollback, and remove older installer-owned releases.
  local previous="" current=""
  if [[ -L "$app_root/previous" ]]; then previous=$(readlink "$app_root/previous"); fi
  if [[ -L "$app_root/current" ]]; then current=$(readlink "$app_root/current"); fi
  if [[ -n "$current" && "$current" != "$release" ]]; then
    previous="$current"
    ln -s "$previous" "$stage/previous"
    mv -Tf -- "$stage/previous" "$app_root/previous"
  fi
  ln -s "$release" "$stage/current"
  mv -Tf -- "$stage/current" "$app_root/current"
  local old
  for old in "$app_root"/releases/*; do
    [[ "$old" == "$release" || "$old" == "$previous" ]] || rm -rf -- "$old"
  done
  if command -v update-desktop-database >/dev/null; then
    update-desktop-database "${DATA_DIR}/applications" || true
  fi
  echo "  installed: $version; launch $tool or use the application menu"
)

if should_install claude cli; then install_claude; fi
if should_install codex cli; then install_codex; fi
if should_install chatgpt gui; then
  install_desktop chatgpt https://persistent.oaistatic.com/codex-app-prod/linux/deb usr/lib/chatgpt/ChatGPT
fi
if should_install claude-desktop gui; then
  install_desktop claude-desktop https://downloads.claude.ai/claude-desktop/apt/stable usr/lib/claude-desktop/claude-desktop
fi
