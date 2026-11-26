#!/bin/sh
# The full laptop system in a VM with 3D graphics (virgl), kept on a disk image
# in ~/VMs/thinkpad-vm. Needs the host packages qemu-desktop and edk2-ovmf.
#
#   tools/vm-install.sh install   # first time: boot the official NixOS minimal ISO
#   tools/vm-install.sh           # later: boot the installed system
#
# The ISO is the file VM_ISO (default: the newest ~/.cache/nixos-minimal-*.iso). The VM sees this
# repository as a read-only folder (9p) with the tag "config". README section 9 has the steps.
# Click into the window and press Ctrl+Alt+G to send all keys (Super) to the VM.
set -eu
dir=${VM_DIR:-$HOME/VMs/thinkpad-vm}
repo=$(cd "$(dirname "$0")/.." && pwd)
ovmf=/usr/share/edk2/x64

mkdir -p "$dir"
[ -f "$dir/disk.qcow2" ] || qemu-img create -f qcow2 "$dir/disk.qcow2" 120G
[ -f "$dir/efivars.fd" ] || cp "$ovmf/OVMF_VARS.4m.fd" "$dir/efivars.fd"

boot=
if [ "${1:-}" = install ]; then
  iso=${VM_ISO:-$(find "$HOME/.cache" -maxdepth 1 -name "nixos-minimal-*-x86_64-linux.iso" | sort | tail -1)}
  [ -f "$iso" ] || { echo "error: put the official nixos-minimal ISO in ~/.cache or set VM_ISO" >&2; exit 1; }
  boot="-cdrom $iso -boot once=d"
fi

# shellcheck disable=SC2086
exec qemu-system-x86_64 -name thinkpad-vm -enable-kvm -machine q35 -cpu host -smp 6 -m 8G \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf/OVMF_CODE.4m.fd" \
  -drive if=pflash,format=raw,file="$dir/efivars.fd" \
  -drive file="$dir/disk.qcow2",if=virtio,discard=unmap \
  -device virtio-vga-gl,xres=1920,yres=1200 -display gtk,gl=on,zoom-to-fit=on \
  -device virtio-tablet-pci -device virtio-keyboard-pci -device virtio-rng-pci \
  -device intel-hda -device hda-duplex \
  -nic user,model=virtio-net-pci \
  -virtfs local,path="$repo",mount_tag=config,security_model=none,readonly=on \
  $boot
