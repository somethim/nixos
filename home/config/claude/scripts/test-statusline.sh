#!/bin/bash
# Checks the home-folder shortening in statusline.sh (cwd shown as ~ only on a path boundary).
dir=$(cd "$(dirname "$0")" && pwd)
fail=0
check() { # cwd expected
  out=$(echo "{\"cwd\":\"$1\"}" | HOME=/home/x bash "$dir/statusline.sh" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
  case "$out" in *"$2"*) ;; *) echo "FAIL $1: want $2, got $out"; fail=1 ;; esac
  case "$1" in /home/xy|/other) case "$out" in *"~"*) echo "FAIL $1: shortened: $out"; fail=1 ;; esac ;; esac
}
check /home/x "~"
check /home/x/a "~/a"
check /home/xy "/home/xy"
check /other "/other"
exit $fail
