#!/usr/bin/env bash
# Applies pkgs/desktop-shell-weather-status.patch to the upstream bin/omarchy-weather-status and runs it
# with a fake curl and fake helpers in a throwaway HOME.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/src/bin" "$tmp/stub" "$tmp/home/.local/state/omarchy/settings"
# The upstream script from the locked desktop-shell flake input.
upstream="$(nix eval --raw --impure --expr "(builtins.getFlake \"git+file://$repo_dir\").inputs.desktop-shell.outPath")"
cp "$upstream/bin/omarchy-weather-status" "$tmp/src/bin/"
chmod u+w "$tmp/src/bin/omarchy-weather-status"
(cd "$tmp/src" && patch -p1 -s <"$repo_dir/pkgs/desktop-shell-weather-status.patch")
export HOME="$tmp/home" PATH="$tmp/stub:$PATH" CURL_LOG="$tmp/curl.log"
file="$HOME/.local/state/omarchy/settings/weather.json"
fail() { echo "FAIL: $*" >&2; exit 1; }
printf '#!/bin/sh\necho "$@" >>"$CURL_LOG"\nprintf "+12°C|↗5km/h"\n' >"$tmp/stub/curl"
printf '#!/bin/sh\n[ -n "$FAKE_PLACE" ] && echo "$FAKE_PLACE"\n' >"$tmp/stub/omarchy-weather-location"
printf '#!/bin/sh\nshift\nprintf "%%s" "$*"\n' >"$tmp/stub/omarchy-i18n"
chmod +x "$tmp"/stub/*
run() { : >"$CURL_LOG"; FAKE_PLACE="${1:-}" bash "$tmp/src/bin/omarchy-weather-status"; }

echo '{"name":"","latitude":41.33,"longitude":19.82,"source":"geoclue"}' >"$file"
out="$(run "IP City")"
grep -q 'https://wttr.in/41.33,19.82?' "$CURL_LOG" || fail "coordinates not in the URL: $(cat "$CURL_LOG")"
case "$out" in *"IP City"*) fail "IP city used: $out" ;; esac

echo '{"name":"Malibu","latitude":34.03,"longitude":-118.68}' >"$file"
out="$(run "IP City")"
grep -q 'https://wttr.in/34.03,-118.68?' "$CURL_LOG" || fail "stored coordinates: $(cat "$CURL_LOG")"
case "$out" in *Malibu*) ;; *) fail "stored name missing: $out" ;; esac

echo '{"name":"Malibu"}' >"$file"
run "Malibu" >/dev/null
grep -q 'https://wttr.in/Malibu?' "$CURL_LOG" || fail "name only: $(cat "$CURL_LOG")"

rm "$file"
run "Paris" >/dev/null
grep -q 'https://wttr.in/Paris?' "$CURL_LOG" || fail "no file: $(cat "$CURL_LOG")"
echo ok
