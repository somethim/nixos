#!/bin/sh
# Evaluate (and optionally build) in a throwaway Nix container; run under the heavy lock:
#   flock /tmp/claude-1000/heavy.lock nice -n 10 tools/eval.sh [attr ...]
cd "$(dirname "$0")/.." && git add -A && docker run --rm -v nixstore:/nix -v "$PWD":/src nixos/nix:latest sh -c '
  git config --global --add safe.directory /src; cd /src
  export NIX_CONFIG="experimental-features = nix-command flakes
max-jobs = 2
cores = 4"
  if [ $# -eq 0 ]; then
    # Keep the exit status of nix: a pipe returns the status of tail only, and
    # pipefail would also fail when grep filters out every line.
    { nix eval --raw .#nixosConfigurations.thinkpad.config.system.build.toplevel.drvPath 2>&1; echo $? >/tmp/rc; } |
      grep -vE "^(copying|unpacking|fetching|warning: Git tree)" | tail -25
  else
    { nix build --no-link --print-out-paths -L "$@" 2>&1; echo $? >/tmp/rc; } |
      grep -vE "^(copying|unpacking|fetching)" | tail -40
  fi
  chown 1000:1000 flake.lock
  exit "$(cat /tmp/rc)"' sh "$@"
