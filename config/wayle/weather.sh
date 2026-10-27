#!/usr/bin/env bash
# Weather for the Wayle bar from MET Norway (api.met.no) -- no API key.
#
# Replaces Wayle's built-in weather module: its only keyless provider,
# open-meteo, is unreachable from this network (the forecast server sits on
# Hetzner, which the ISP blocks, and it also refuses the iVPN exit).
#
# Location: `location = "..."` under [modules.weather] in
# ~/.config/wayle/local.toml (kept out of git). A city name is turned into
# coordinates once via OpenStreetMap Nominatim and cached; "lat,lon" is used
# as-is.
#
# Prints one JSON line for the custom module: temp, desc, feels-like-ish
# details for the tooltip, and `alt` (icon key, see icon-map in config.toml).
# On a failed fetch it re-prints the last good result for up to 3 hours.
set -uo pipefail

UA="simple_nix-wayle-weather/1.0 github.com/CodeSpartan/simple_nix"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wayle-weather"
LOCAL_TOML="$HOME/.config/wayle/local.toml"
mkdir -p "$CACHE"

fallback() {
  if [[ -f "$CACHE/last.json" ]] && (( $(date +%s) - $(stat -c %Y "$CACHE/last.json") < 10800 )); then
    cat "$CACHE/last.json"
  else
    printf '{"temp":"--","desc":"%s","details":"","alt":"default"}\n' "$1"
  fi
  exit 0
}

location=$(sed -n 's/^[[:space:]]*location[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$LOCAL_TOML" 2>/dev/null | head -1)
[[ -n "$location" ]] || fallback "no location in local.toml"

if [[ "$location" =~ ^[[:space:]]*(-?[0-9.]+)[[:space:]]*,[[:space:]]*(-?[0-9.]+)[[:space:]]*$ ]]; then
  lat=${BASH_REMATCH[1]} lon=${BASH_REMATCH[2]}
else
  geo="$CACHE/geo.json"
  if [[ ! -s "$geo" || "$(jq -r .q "$geo" 2>/dev/null)" != "$location" ]]; then
    hit=$(curl -sf -m 15 -A "$UA" -G "https://nominatim.openstreetmap.org/search" \
            --data-urlencode "q=$location" -d format=json -d limit=1 | jq -c '.[0] // empty') \
      || fallback "location lookup failed"
    [[ -n "$hit" ]] || fallback "location not found"
    jq -c --arg q "$location" '{q: $q, lat: .lat, lon: .lon}' <<<"$hit" > "$geo"
  fi
  # MET asks for at most 4 decimals
  lat=$(jq -r '.lat | tonumber * 10000 | round / 10000' "$geo")
  lon=$(jq -r '.lon | tonumber * 10000 | round / 10000' "$geo")
fi

data=$(curl -sf -m 20 -A "$UA" \
  "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$lat&lon=$lon") \
  || fallback "fetch failed"

out=$(jq -c --arg place "${location%%,*}" '
  def word: {
    clearsky: "Clear", fair: "Fair", partlycloudy: "Partly cloudy", cloudy: "Cloudy", fog: "Fog",
    lightrain: "Light rain", rain: "Rain", heavyrain: "Heavy rain",
    lightrainshowers: "Light showers", rainshowers: "Showers", heavyrainshowers: "Heavy showers",
    lightsleet: "Light sleet", sleet: "Sleet", heavysleet: "Heavy sleet",
    lightsleetshowers: "Light sleet", sleetshowers: "Sleet showers", heavysleetshowers: "Heavy sleet",
    lightsnow: "Light snow", snow: "Snow", heavysnow: "Heavy snow",
    lightsnowshowers: "Light snow", snowshowers: "Snow showers", heavysnowshowers: "Heavy snow"
  }[.] // (if test("thunder") then "Thunder" else . end);
  def icon:
    if   test("thunder") then "thunder"
    elif test("snow")    then "snow"
    elif test("sleet")   then "sleet"
    elif test("^light(rain|rainshowers)") then "drizzle"
    elif test("rain")    then "rain"
    elif . == "fog"      then "fog"
    elif . == "cloudy"   then "cloudy"
    elif test("^(fair|partlycloudy)_night") then "partly-night"
    elif test("^(fair|partlycloudy)")       then "partly-day"
    elif . == "clearsky_night" then "clear-night"
    else "clear-day" end;
  .properties.timeseries
  | (map(select((.time | fromdateiso8601) > (now - 3600))) | first) as $t
  | $t.data as $d
  | ($d.next_1_hours.summary.symbol_code // $d.next_6_hours.summary.symbol_code // "cloudy") as $sym
  | ($sym | sub("_(day|night|polartwilight)$"; "")) as $base
  | {
      temp: ($d.instant.details.air_temperature | round + 0),   # + 0 turns -0 into 0
      desc: ($base | word),
      details: "\($place): \($base | word), \($d.instant.details.air_temperature)°C · wind \($d.instant.details.wind_speed) m/s · humidity \($d.instant.details.relative_humidity | round)%"
               + (if ($d.next_1_hours.details.precipitation_amount // 0) > 0
                  then " · \($d.next_1_hours.details.precipitation_amount) mm next hour" else "" end),
      alt: ($sym | icon)
    }' <<<"$data") || fallback "bad response"

printf '%s\n' "$out" | tee "$CACHE/last.json"
