#!/usr/bin/env bash
# Run every update-*.sh: messengers (user Flatpaks), AI CLIs, Craft apps.
# Each can also be run on its own. No sudo needed.
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
failed=()
for s in messengers ai crafts; do
  echo "######## update-$s.sh"
  "$REPO/update-$s.sh" || failed+=("update-$s.sh")
  echo
done
if (( ${#failed[@]} )); then
  echo "Problems in: ${failed[*]} (see their summaries above)"
  exit 1
fi
echo "All updates done."
