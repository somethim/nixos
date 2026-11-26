#!/usr/bin/env bash
# Run inside the test VM to apply the current host repository: bash /mnt/config/tools/vm-update.sh [boot]
set -euo pipefail
mountpoint -q /mnt/config || { sudo mkdir -p /mnt/config && sudo mount -t 9p -o trans=virtio,ro config /mnt/config; }
rsync -a --delete --exclude hosts/thinkpad-vm/hardware-configuration.nix /mnt/config/ ~/nixos-config/
git -C ~/nixos-config add -A
# "boot" applies the change at the next start (needed when the login manager changes).
sudo nixos-rebuild "${1:-switch}" --flake ~/nixos-config#thinkpad-vm
echo "Done. Reboot the VM to restart the desktop: reboot"
