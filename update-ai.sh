#!/usr/bin/env bash
# Update the claude / codex CLIs in ~/.local/bin (scripts/install-ai-tools.sh).
# Running apps keep running the old version until you restart them; nothing
# is closed. No sudo needed. ./update-apps.sh runs all update-*.sh scripts.
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
source "$REPO/scripts/update-lib.sh"

export PATH="$HOME/.local/bin:$PATH"

echo "==> Updating claude / codex..."
"$REPO/scripts/install-ai-tools.sh" cli || warnings+=("claude/codex: update failed (see above)")

finish
