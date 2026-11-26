#!/usr/bin/env bash
# Exercises home/scripts/system-update-check and system-update-available with fake nix, fwupdmgr
# and desktop-shell-ipc in a throwaway HOME. No network, no Nix needed.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" SYSTEM_UPDATE_REPO="$tmp/repo" SYSTEM_UPDATE_STATE="$tmp/state" \
  SYSTEM_UPDATE_POWER="$tmp/power" SYSTEM_UPDATE_RUN="$tmp/run" FAKE_LOG="$tmp/calls.log"
mkdir -p "$HOME" "$SYSTEM_UPDATE_REPO" "$tmp/bin" "$tmp/power/AC" "$tmp/run/booted-system" "$tmp/store/k1" "$tmp/store/k2"
fail() { echo "FAIL: $*" >&2; cat "$tmp/err.log" >&2 2>/dev/null; exit 1; }
summary() { cat "$SYSTEM_UPDATE_STATE/summary.txt"; }
check() { PATH="$tmp/bin:$PATH" "$repo_dir/home/scripts/system-update-check" "$@" 2>>"$tmp/err.log"; }
lock() { printf '{"nodes":{"root":{"inputs":{"nixpkgs":"nixpkgs"}},"nixpkgs":{"locked":{"rev":"%s","narHash":"%s","lastModified":%s}}},"root":"root","version":7}\n' "$1" "$1" "$2"; }

lock aaaaaaa1111 1761000000 >"$SYSTEM_UPDATE_REPO/flake.lock"
touch "$SYSTEM_UPDATE_REPO/flake.nix"
ln -s "$tmp/store/k1" "$tmp/run/booted-system/kernel"

# The fakes. FAKE_NEW is the lock that "nix flake update" writes, FAKE_FW the fwupd JSON.
cat >"$tmp/bin/nix" <<'EOF'
#!/bin/sh
echo "nix $*" >>"$FAKE_LOG"
[ -z "${FAKE_OFFLINE:-}" ] || exit 1
case "$1 $2" in
  "flake update") while [ $# -gt 0 ]; do [ "$1" = --output-lock-file ] && cp "$FAKE_NEW" "$2"; shift; done ;;
  "store diff-closures") echo "hello: 2.12 -> 2.13" ;;
  build) while [ $# -gt 0 ]; do
      if [ "$1" = --out-link ]; then mkdir -p "$2"; ln -sfn "$FAKE_KERNEL" "$2/kernel"; fi; shift; done ;;
esac
EOF
cat >"$tmp/bin/fwupdmgr" <<'EOF'
#!/bin/sh
echo "fwupdmgr $*" >>"$FAKE_LOG"
[ "$1" = get-updates ] || exit 0
[ -n "${FAKE_FW:-}" ] || exit 2
cat "$FAKE_FW"
EOF
cat >"$tmp/bin/desktop-shell-ipc" <<'EOF'
#!/bin/sh
echo "ipc $*" >>"$FAKE_LOG"
EOF
chmod +x "$tmp/bin"/*
cat >"$tmp/fw.json" <<'EOF'
{"Devices":[{"Name":"ThinkPad BIOS","Version":"1.10","Flags":["updatable","needs-reboot","require-ac"],"Releases":[{"Version":"1.11"}]}]}
EOF
export FAKE_KERNEL="$tmp/store/k2"

# 1. A changed input: marker, summary, build, reboot for the new kernel, bar refresh.
export FAKE_NEW="$tmp/new.lock"; lock bbbbbbb2222 1762000000 >"$FAKE_NEW"
check
[ -e "$SYSTEM_UPDATE_STATE/available" ] || fail "marker missing for a changed input"
summary | grep -q 'nixpkgs: aaaaaaa (2025-10-20) -> bbbbbbb (2025-11-01)' || fail "input line: $(summary)"
summary | grep -q 'hello: 2.12 -> 2.13' || fail "package diff: $(summary)"
summary | grep -q 'Reboot after the packages: kernel' || fail "kernel reboot: $(summary)"
grep -q 'nix build .*--reference-lock-file' "$FAKE_LOG" || fail "build must use the newer lock file"
grep -q 'ipc -q omarchy.system-update refresh' "$FAKE_LOG" || fail "bar not refreshed"
[ "$("$repo_dir/home/scripts/system-update-available")" = "Updates: 1 inputs, 0 firmware, reboot needed" ] || fail "headline"
"$repo_dir/home/scripts/system-update-available" >/dev/null || fail "available must exit 0"
[ "$(jq -r .nodes.nixpkgs.locked.rev "$SYSTEM_UPDATE_REPO/flake.lock")" = aaaaaaa1111 ] || fail "the checkout must not change"

# 2. The same check again with --if-stale: nothing runs.
: >"$FAKE_LOG"; check --if-stale
[ ! -s "$FAKE_LOG" ] || fail "a fresh check must stop --if-stale: $(cat "$FAKE_LOG")"

# 2b. Right click: dismiss hides this set; the same set after a new check stays hidden;
#     a newer set shows again.
avail() { "$repo_dir/home/scripts/system-update-available" "$@"; }
avail --dismiss
avail >/dev/null && fail "a dismissed update must hide the icon"
check
avail >/dev/null && fail "the same update must stay hidden after a new check"
lock ccccccc3333 1763000000 >"$FAKE_NEW"; check
avail >/dev/null || fail "a newer update must show the icon again"
lock bbbbbbb2222 1762000000 >"$FAKE_NEW"

# 3. Nothing new: the marker goes.
cp "$SYSTEM_UPDATE_REPO/flake.lock" "$FAKE_NEW"
check
[ ! -e "$SYSTEM_UPDATE_STATE/available" ] || fail "marker must go when nothing waits"
summary | grep -q 'Nothing.' || fail "needs section: $(summary)"
"$repo_dir/home/scripts/system-update-available" >/dev/null && fail "available must exit 1"

# 4. Firmware only: marker, versions, reboot and power.
export FAKE_FW="$tmp/fw.json"
check
[ -e "$SYSTEM_UPDATE_STATE/available" ] || fail "marker missing for firmware"
summary | grep -q 'ThinkPad BIOS: 1.10 -> 1.11' || fail "firmware line"
summary | grep -q 'Reboot for the firmware: ThinkPad BIOS' || fail "firmware reboot"
summary | grep -q 'Power connected for the firmware: ThinkPad BIOS' || fail "firmware power"
unset FAKE_FW

# 5. On battery: no build, and the summary says so.
mkdir "$tmp/power/BAT0"; echo Battery >"$tmp/power/BAT0/type"; echo Discharging >"$tmp/power/BAT0/status"
lock bbbbbbb2222 1762000000 >"$FAKE_NEW"; : >"$FAKE_LOG"
check
grep -q 'nix build' "$FAKE_LOG" && fail "no build on battery"
summary | grep -q 'runs on battery' || fail "battery text: $(summary)"
[ -e "$SYSTEM_UPDATE_STATE/available" ] || fail "an input change is an update even without the build"
rm -r "$tmp/power/BAT0"

# 6. Offline: the check ends without an error and keeps the last result.
export FAKE_OFFLINE=1
check || fail "offline must not fail"
[ -e "$SYSTEM_UPDATE_STATE/available" ] || fail "offline must keep the marker"
echo ok
