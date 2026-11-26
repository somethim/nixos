#!/bin/sh
# Boot the test VM headless (KVM) in the Nix container and save screenshots of
# the desktop to tools/out/vm-*.png.
#   flock /tmp/claude-1000/heavy.lock nice -n 10 tools/vm-screenshot.sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p tools/out
git add -A
docker run --rm --device /dev/kvm -v nixstore:/nix -v "$PWD":/src -v "$PWD/tools/out":/out nixos/nix:latest sh -c '
  set -eu
  git config --global --add safe.directory /src; cd /src
  export NIX_CONFIG="experimental-features = nix-command flakes"
  vm=$(nix build --no-link --print-out-paths .#nixosConfigurations.vm.config.system.build.vm)
  mon=/tmp/mon
  QEMU_OPTS="-display none -monitor unix:$mon,server,nowait -serial file:/out/vm-serial.log" NIX_DISK_IMAGE=/tmp/vm.qcow2 \
    "$vm"/bin/run-desktop-vm-vm >/out/vm-console.log 2>&1 &
  shot() { sleep "$1"; echo "screendump /tmp/$2.ppm" | nix run nixpkgs#socat -- - UNIX-CONNECT:$mon >/dev/null;
           sleep 1; nix run nixpkgs#imagemagick -- /tmp/$2.ppm /out/$2.png; }
  key() { echo "sendkey $1" | nix run nixpkgs#socat -- - UNIX-CONNECT:$mon >/dev/null; }
  # Type a command into the focused terminal (letters, digits, and the few symbols below).
  type() { sleep 2; key spc; key spc; printf "%s" "$1" | while IFS= read -r -n1 c; do case "$c" in
      " ") k=spc;; ".") k=dot;; "/") k=slash;; "-") k=minus;; "{") k=shift-bracket_left;; "}") k=shift-bracket_right;;
      "\"") k=shift-apostrophe;; ":") k=shift-semicolon;; *) k=$c;; esac; key $k; done; key ret; }
  shot 120 vm-1-desktop
  # Bar panels through the shell IPC, typed into a terminal (Super+Return).
  key meta_l-ret; sleep 6
  type "desktop-shell-ipc omarchy.weather open";   shot 5 vm-9-weather-panel;  key esc
  type "desktop-shell-ipc omarchy.clock open";     shot 5 vm-11-clock-panel;   key esc
  type "desktop-shell-ipc shell toggle omarchy.menu {\"menu\":\"apps\"}";  shot 5 vm-10-apps-menu; key esc
  # The root menu, then Setup (5th row) and Update (8th row) with the arrow keys.
  sleep 2; type "desktop-shell-ipc shell summon omarchy.menu {\"menu\":\"root\"}";   shot 5 vm-12-root-menu
  for n in 1 2 3 4; do key down; done; key ret;                                        shot 3 vm-13-setup-menu;  key esc; key esc
  sleep 2; type "desktop-shell-ipc shell summon omarchy.menu {\"menu\":\"root\"}"; sleep 3
  for n in 1 2 3 4 5 6 7; do key down; done; key ret;                                  shot 3 vm-14-update-menu; key esc; key esc
  # The polkit dialog of the shell (password or fingerprint) for an action that needs authentication.
  sleep 2; type "systemctl restart systemd-journald";                                        shot 6 vm-15-polkit;      key esc
  key meta_l-q; sleep 2
  key meta_l-spc;            shot 4 vm-2-launcher;    key esc
  key meta_l-esc;            shot 4 vm-3-system-menu; key esc
  key meta_l-k;              shot 4 vm-4-keys;        key esc
  key meta_l-ret; sleep 4; key meta_l-ret
  shot 6 vm-5-two-terminals
  key meta_l-alt-f;   shot 4 vm-6-focus-mode
  key meta_l-left;           shot 3 vm-7-focus-mode-left
  key meta_l-alt-f;   shot 4 vm-8-focus-mode-off
  echo quit | nix run nixpkgs#socat -- - UNIX-CONNECT:$mon >/dev/null || true
  chown -R 1000:1000 /out'
ls tools/out | grep vm
