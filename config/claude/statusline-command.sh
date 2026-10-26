#!/usr/bin/env bash
# Claude Code status line (single line). Fields are hidden when absent/null.
export LC_ALL=C

JQ=$(command -v jq 2>/dev/null || echo /run/current-system/sw/bin/jq)
input=$(cat)

# Extract everything in one jq call, joined by the unit separator (non-whitespace IFS keeps empties).
IFS=$'\x1f' read -r model cwd ctx_tok ctx_size ctx_pct five_pct five_reset seven_pct seven_reset \
  transcript cache_state cache_exp cache_cause effort thinking < <(
  printf '%s' "$input" | "$JQ" -r '
    [ (.model.display_name // ""),
      (.workspace.current_dir // .cwd // ""),
      (.context_window.total_input_tokens // ""),
      (.context_window.context_window_size // ""),
      (.context_window.used_percentage // ""),
      (.rate_limits.five_hour.used_percentage // ""),
      (.rate_limits.five_hour.resets_at // ""),
      (.rate_limits.seven_day.used_percentage // ""),
      (.rate_limits.seven_day.resets_at // ""),
      (.transcript_path // ""),
      (if .prompt_cache.caching_observed == true
         then (if .prompt_cache.warm == true then "warm" else "cold" end) else "" end),
      (.prompt_cache.expires_at // ""),
      (.prompt_cache.last_miss_cause.causes[0] // ""),
      (.effort.level // ""),
      (if .thinking.enabled == true then "on"
       elif .thinking.enabled == false then "off" else "" end)
    ] | map(tostring) | join("\u001f")'
)

RST=$'\033[0m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'
CYN=$'\033[36m'; MAG=$'\033[35m'

color_pct() { # $1 = percentage (may be float)
  local p=${1%.*}; p=${p:-0}
  if   (( p >= 85 )); then printf '%s' "$RED"
  elif (( p >= 60 )); then printf '%s' "$YEL"
  else printf '%s' "$GRN"; fi
}

fmt_tok() {
  local n=${1%.*}
  if   (( n >= 1000000 )); then
    local t=$(( (n % 1000000) / 100000 ))
    if (( t == 0 )); then printf '%dM' $(( n / 1000000 ))
    else printf '%d.%dM' $(( n / 1000000 )) "$t"; fi
  elif (( n >= 1000 )); then printf '%dk' $(( (n + 500) / 1000 ))
  else printf '%d' "$n"; fi
}

fmt_dur() { # seconds -> 3d4h / 1h47m / 12m
  local s=${1%.*}
  (( s < 0 )) && s=0
  local d=$(( s / 86400 )) h=$(( (s % 86400) / 3600 )) m=$(( (s % 3600) / 60 ))
  if   (( d > 0 )); then printf '%dd%dh' "$d" "$h"
  elif (( h > 0 )); then printf '%dh%02dm' "$h" "$m"
  elif (( m > 0 )); then printf '%dm' "$m"
  else printf '<1m'; fi
}

# Whole-session fresh tokens (input + output + cache_creation; cache reads excluded), cached by size.
session_fresh() {
  local tp=$1 size key dir cf csize csum
  [ -n "$tp" ] && [ -r "$tp" ] || return 1
  size=$(stat -c %s "$tp" 2>/dev/null) || return 1
  key=$(printf '%s' "$tp" | cksum | cut -d' ' -f1)
  dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
  cf="$dir/$key"
  if [ -r "$cf" ]; then
    read -r csize csum < "$cf"
    if [ "$csize" = "$size" ] && [ -n "$csum" ]; then printf '%s' "$csum"; return 0; fi
  fi
  csum=$("$JQ" -n -R '
    [ inputs | fromjson? | select(.message.usage? != null)
      | {id: (.message.id // .uuid // (input_line_number | tostring)), u: .message.usage} ]
    | reverse | unique_by(.id)
    | map((.u.input_tokens // 0) + (.u.output_tokens // 0) + (.u.cache_creation_input_tokens // 0))
    | add // 0' "$tp" 2>/dev/null) || return 1
  [ -n "$csum" ] || return 1
  mkdir -p "$dir" 2>/dev/null && printf '%s %s\n' "$size" "$csum" > "$cf" 2>/dev/null
  printf '%s' "$csum"
}

now=$(date +%s)
parts=()

[ -n "$model" ] && parts+=("${CYN}${model}${RST}")

if [ -n "$ctx_tok" ]; then
  s="ctx $(fmt_tok "$ctx_tok")"
  [ -n "$ctx_size" ] && s+="/$(fmt_tok "$ctx_size")"
  if [ -n "$ctx_pct" ]; then
    s+=" $(printf '%.0f' "$ctx_pct")%"
    parts+=("$(color_pct "$ctx_pct")${s}${RST}")
  else
    parts+=("$s")
  fi
fi

if [ -n "$five_pct" ]; then
  s="5h $(printf '%.0f' "$five_pct")%"
  [ -n "$five_reset" ] && s+=" ↻$(fmt_dur $(( ${five_reset%.*} - now )))"
  parts+=("$(color_pct "$five_pct")${s}${RST}")
fi
if [ -n "$seven_pct" ]; then
  s="7d $(printf '%.0f' "$seven_pct")%"
  [ -n "$seven_reset" ] && s+=" ↻$(fmt_dur $(( ${seven_reset%.*} - now )))"
  parts+=("$(color_pct "$seven_pct")${s}${RST}")
fi

if fresh=$(session_fresh "$transcript") && [ -n "$fresh" ]; then
  parts+=("fresh $(fmt_tok "$fresh")")
fi

[ -n "$cwd" ] && parts+=("${MAG}$(basename "$cwd")${RST}")

case "$cache_state" in
  warm)
    if [ -n "$cache_exp" ]; then
      parts+=("${GRN}cache $(fmt_dur $(( ${cache_exp%.*} - now )))${RST}")
    else
      parts+=("${GRN}cache warm${RST}")
    fi ;;
  cold)
    parts+=("${YEL}cache cold${cache_cause:+: $cache_cause}${RST}") ;;
esac

[ -n "$effort" ]   && parts+=("effort $effort")
[ -n "$thinking" ] && parts+=("think $thinking")

sep=" ${DIM}·${RST} "
out=""
for p in "${parts[@]}"; do
  if [ -z "$out" ]; then out=$p; else out+="$sep$p"; fi
done
printf '%s\n' "$out"
