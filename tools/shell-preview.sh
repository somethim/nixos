#!/bin/sh
# Render the Quickshell shell (home/shell) in a headless sway inside the Nix
# container and save screenshots plus the shell log to tools/out/.
#   flock /tmp/claude-1000/heavy.lock nice -n 10 tools/shell-preview.sh
set -eu
cd "$(dirname "$0")/.."
# Only the preview files are replaced: tools/out also holds the VM screenshots and logs.
mkdir -p tools/out && rm -f tools/out/sway.log tools/out/shell.log tools/out/picker-*.png
docker run --rm -v nixstore:/nix -v "$PWD":/src:ro -v "$PWD/tools/out":/out nixos/nix:latest \
  sh /src/tools/preview-in-container.sh
ls tools/out
