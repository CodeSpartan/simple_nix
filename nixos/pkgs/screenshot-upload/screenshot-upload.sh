#!/usr/bin/env bash
# screenshot-upload <gyazo|cloudinary> [file...]
#
# Uploads images (the files, or a PNG on stdin when none are given), copies
# the link(s) to the clipboard, opens them in Brave and shows a notification.
#   Shift+Print / Ctrl+Print: `flameshot gui --raw | screenshot-upload ...`
#   Flameshot's "Open with" button: the "Upload to ..." entries pass a file.
#   Dolphin: right-click images -> "Upload to" (kio service menu).
#
# Credentials (agenix, see nixos/security.nix):
#   /run/agenix/gyazo-token  the access token from gyazo.com/oauth/applications
#   /run/agenix/cloudinary   CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@<cloud_name>
set -uo pipefail

service="${1:-}"
[ $# -gt 0 ] && shift

case "$service" in
  gyazo) name=Gyazo ;;
  cloudinary) name=Cloudinary ;;
  *) echo "usage: screenshot-upload <gyazo|cloudinary> [file...]" >&2; exit 2 ;;
esac

fail() {
  notify-send -a Screenshot -u critical "Upload to $name failed" "$1"
  echo "screenshot-upload: $1" >&2
  exit 1
}

tmp=""
trap 'if [ -n "$tmp" ]; then rm -f "$tmp"; fi' EXIT
if [ $# -eq 0 ]; then
  tmp="$(mktemp --suffix=.png)"
  cat > "$tmp"
  # Nothing (or not a PNG) came in: the capture was cancelled with Esc.
  [ "$(head -c 4 "$tmp" 2>/dev/null | tail -c 3)" = "PNG" ] || exit 0
  set -- "$tmp"
fi

# Sets $url (empty on failure, with the server's answer in $resp).
upload() {
  local file="$1" form
  # curl -F treats ; and " in a bare filename as syntax: quote it.
  form="${file//\\/\\\\}"
  form="@\"${form//\"/\\\"}\""
  url=""
  case "$service" in
    gyazo)
      secret=/run/agenix/gyazo-token
      [ -r "$secret" ] || fail "No token at $secret"
      token="$(tr -d '[:space:]' < "$secret")"
      # Token goes in through stdin (curl -K -), not argv, so `ps` can't see it.
      resp="$(printf 'form-string = "access_token=%s"\n' "$token" |
        curl -sS --max-time 60 -K - -F "imagedata=$form" \
          https://upload.gyazo.com/api/upload 2>&1)" || return 0
      url="$(jq -r '.permalink_url // empty' <<<"$resp" 2>/dev/null)"
      ;;
    cloudinary)
      secret=/run/agenix/cloudinary
      [ -r "$secret" ] || fail "Not set up yet: no $secret"
      # The dashboard's "API environment variable":
      #   CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@<cloud_name>
      cfg="$(sed -n 's|^.*cloudinary://||p' "$secret" | tr -d '[:space:]')"
      api_key="${cfg%%:*}"
      rest="${cfg#*:}"
      api_secret="${rest%@*}"
      cloud="${rest##*@}"
      [ -n "$api_key" ] && [ -n "$api_secret" ] && [ -n "$cloud" ] && [ "$cfg" != "$rest" ] ||
        fail "$secret should hold CLOUDINARY_URL=cloudinary://key:secret@cloud"
      # Signed upload: sha1 of the sorted params + the API secret.
      ts="$(date +%s)"
      sig="$(printf 'timestamp=%s%s' "$ts" "$api_secret" | sha1sum | cut -d' ' -f1)"
      resp="$(printf 'form-string = "api_key=%s"\nform-string = "timestamp=%s"\nform-string = "signature=%s"\n' \
          "$api_key" "$ts" "$sig" |
        curl -sS --max-time 60 -K - -F "file=$form" \
          "https://api.cloudinary.com/v1_1/$cloud/image/upload" 2>&1)" || return 0
      url="$(jq -r '.secure_url // empty' <<<"$resp" 2>/dev/null)"
      ;;
  esac
}

urls=()
for f in "$@"; do
  upload "$f"
  if [ -n "$url" ]; then
    urls+=("$url")
  else
    msg="$(jq -r '.message // .error.message // .error // empty' <<<"$resp" 2>/dev/null)"
    notify-send -a Screenshot -u critical "Upload to $name failed: ${f##*/}" "${msg:-${resp:0:300}}"
  fi
done
[ ${#urls[@]} -gt 0 ] || exit 1

printf '%s\n' "${urls[@]}" | head -c -1 | wl-copy
for u in "${urls[@]}"; do
  setsid -f brave "$u" >/dev/null 2>&1
done
if [ ${#urls[@]} -eq 1 ]; then
  notify-send -a Screenshot "Uploaded to $name" "Link copied: ${urls[0]}"
else
  notify-send -a Screenshot "Uploaded ${#urls[@]} images to $name" "Links copied, one per line"
fi
