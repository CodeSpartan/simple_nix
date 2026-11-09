#!/usr/bin/env bash
# Check PhotoCraft / PdfCraft / WordCraft releases. A new one is written into
# nixos/programs.nix and committed (not pushed); ./install.sh installs it.
# Running apps keep running the old version until you restart them; nothing
# is closed. No sudo needed. ./update-apps.sh runs all update-*.sh scripts.
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
source "$REPO/scripts/update-lib.sh"

echo "==> Checking PhotoCraft / PdfCraft / WordCraft releases..."
# These are Nix packages (nixos/pkgs/storytold-craft), so this only bumps
# version + hash in programs.nix and commits that; ./install.sh installs it.
programs="$REPO/nixos/programs.nix"
craft_bumped=()
# Remember whether programs.nix already had unsaved edits: then don't commit.
git -C "$REPO" diff --quiet -- nixos/programs.nix; programs_dirty=$?
for app in photocraft pdfcraft wordcraft; do
  cur=$(grep -oP "pname = \"$app\"; version = \"\K[^\"]+" "$programs")
  if [[ -z "$cur" ]]; then
    warnings+=("$app: version line not found in programs.nix")
    continue
  fi
  tag=$(curl -sS --max-time 15 "https://api.github.com/repos/storytold/$app/releases/latest" |
        jq -r '.tag_name // empty' 2>/dev/null)
  new=${tag#v}
  if [[ -z "$new" ]]; then
    warnings+=("$app: couldn't check for a new release (network / GitHub rate limit?)")
    continue
  fi
  # Only move forward (sort -V = version order).
  if [[ "$new" == "$cur" || $(printf '%s\n' "$cur" "$new" | sort -V | tail -1) != "$new" ]]; then
    echo "    $app $cur: up to date"
    continue
  fi
  hash=$(curl -sSL --max-time 30 "https://github.com/storytold/$app/releases/download/$tag/SHA256SUMS.txt" |
         awk -v f="$app-$new-linux-x86_64.tar.gz" '$2 == f { print $1 }')
  if [[ ! "$hash" =~ ^[0-9a-f]{64}$ ]]; then
    warnings+=("$app: $new is out but its Linux checksum wasn't found; not bumped")
    continue
  fi
  # Version and hash sit on consecutive lines of that app's block.
  sed -i -E "/pname = \"$app\"; version = /{s/version = \"[^\"]+\"/version = \"$new\"/;n;s/sha256 = \"[0-9a-f]+\"/sha256 = \"$hash\"/}" "$programs"
  echo "    $app $cur -> $new"
  craft_bumped+=("$app $cur -> $new")
done
if (( ${#craft_bumped[@]} )); then
  if (( programs_dirty == 0 )); then
    git -C "$REPO" commit -q -m "chore: bump $(IFS=,; echo "${craft_bumped[*]}" | sed 's/,/, /g')" -- nixos/programs.nix &&
      echo "    committed (not pushed)"
  else
    warnings+=("programs.nix had other unsaved changes, so the Craft bump isn't committed")
  fi
  notes+=("New Craft app versions are set up; run ./install.sh to install them")
fi

finish
