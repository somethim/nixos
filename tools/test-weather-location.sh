#!/usr/bin/env bash
# Exercises home/scripts/weather-location-update with a fake where-am-i in a throwaway HOME.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" WHERE_AM_I="$tmp/where-am-i"
file="$HOME/.local/state/omarchy/settings/weather.json"
fail() { echo "FAIL: $*" >&2; exit 1; }
fake() { printf '#!/bin/sh\nprintf "New location:\\nLatitude:    %s°\\nLongitude:   %s°\\n"\n' "$1" "$2" >"$WHERE_AM_I"; chmod +x "$WHERE_AM_I"; }
run() { "$repo_dir/home/scripts/weather-location-update"; }

fake 41.32749 19.81871
run
[ "$(jq -c . "$file")" = '{"name":"","latitude":41.33,"longitude":19.82,"source":"geoclue"}' ] || fail "first write: $(cat "$file")"

fake 48.85 2.35
run
[ "$(jq .latitude "$file")" = 48.85 ] || fail "the file must follow the position"

echo '{"name":"Malibu"}' >"$file"
run
[ "$(jq -r .name "$file")" = Malibu ] || fail "a location set by hand must stay"

printf '#!/bin/sh\n' >"$WHERE_AM_I"
rm "$file"
run || fail "no position must not fail the unit"
[ ! -e "$file" ] || fail "no position must not write"
echo ok
