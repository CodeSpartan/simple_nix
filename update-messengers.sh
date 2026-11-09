#!/usr/bin/env bash
# Update the messengers that are user Flatpaks (MAX, the user copy of Discord)
# and their runtimes. In fact it updates *every* user Flatpak -- today those
# are the only two. (System Discord: install.sh; Discord PTB: Nix.)
# Running apps keep running the old version until you restart them; nothing
# is closed. No sudo needed. ./update-apps.sh runs all update-*.sh scripts.
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
source "$REPO/scripts/update-lib.sh"

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

finish
