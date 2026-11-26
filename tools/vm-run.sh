#!/bin/sh
# Boot the test VM in a window on this desktop, to try the desktop by hand.
# The VM runs in the Nix container (KVM) and draws through the host's Wayland
# socket. Login is automatic; the user password in the VM is "vm".
# Click into the window: Super and other keys then go to the VM.
# Close the window to stop the VM. Nothing is kept between runs.
#   flock /tmp/claude-1000/heavy.lock nice -n 10 tools/vm-run.sh
set -eu
cd "$(dirname "$0")/.."
git add -A
sock=${XDG_RUNTIME_DIR:?}/${WAYLAND_DISPLAY:?}
exec docker run --rm --device /dev/kvm -v nixstore:/nix -v "$PWD":/src \
  -v "$sock":/run/host/wayland-0 -e WAYLAND_DISPLAY=/run/host/wayland-0 -e XDG_RUNTIME_DIR=/tmp \
  nixos/nix:latest sh -c '
  set -eu
  git config --global --add safe.directory /src; cd /src
  export NIX_CONFIG="experimental-features = nix-command flakes"
  vm=$(nix build --no-link --print-out-paths .#nixosConfigurations.vm.config.system.build.vm)
  QEMU_OPTS="-display gtk,gl=off,zoom-to-fit=on" NIX_DISK_IMAGE=/tmp/vm.qcow2 exec "$vm"/bin/run-desktop-vm-vm'
