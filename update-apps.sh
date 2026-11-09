#!/usr/bin/env bash
# Update the apps install.sh doesn't touch:
#   - user Flatpaks (MAX, the user copy of Discord, ...) and their runtimes
#   - claude / codex CLIs in ~/.local/bin (scripts/install-ai-tools.sh cli)
#   - checks PhotoCraft/PdfCraft/WordCraft releases; a new one is written into
#     nixos/programs.nix and committed, ./install.sh then installs it
# Running apps keep running the old version until you restart them; nothing
# is closed. No sudo needed. Problems are listed at the end, not fatal.
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"
warnings=()
notes=()

echo "==> Checking user Flatpak updates..."
if ! refs=$(timeout 60 flatpak remote-ls --user --updates --columns=ref 2>&1); then
  warnings+=("Flatpak: couldn't check for updates (network?): $refs")
  refs=""
fi

# MAX downloads its .deb from download.max.ru, which doesn't answer through the
# iVPN exit (it does through v2rayN). Check quickly instead of letting flatpak
# hang on it, and skip only MAX if it's unreachable.
if grep -q '/ru\.max\.MAX/' <<<"$refs" &&
   ! curl -sSI --max-time 4 -o /dev/null https://download.max.ru/linux/deb/ 2>/dev/null; then
  warnings+=("MAX: update available but download.max.ru is unreachable (on iVPN?); skipped")
  refs=$(grep -v '/ru\.max\.MAX/' <<<"$refs")
fi

refs=$(sed '/^\s*$/d' <<<"$refs")
if [[ -n "$refs" ]]; then
  echo "$refs" | sed 's/^/    /'
  # shellcheck disable=SC2086  # one ref per word
  flatpak update --user --noninteractive $refs ||
    warnings+=("Flatpak: update failed (see above)")
  flatpak uninstall --user --unused --noninteractive >/dev/null ||
    warnings+=("Flatpak: removing unused runtimes failed")
else
  echo "    nothing to update"
fi

echo "==> Updating claude / codex..."
"$REPO/scripts/install-ai-tools.sh" cli || warnings+=("claude/codex: update failed (see above)")

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

echo
if (( ${#warnings[@]} )); then
  echo "Done, with problems:"
  printf '  ! %s\n' "${warnings[@]}"
  (( ${#notes[@]} )) && printf '  > %s\n' "${notes[@]}"
  exit 1
fi
echo "Done. Restart updated apps to use the new versions."
(( ${#notes[@]} )) && printf '  > %s\n' "${notes[@]}"
exit 0
