#!/usr/bin/env bash
# Install a system from a writable copy of this repository (a git checkout). Run as root in the NixOS
# installer. tools/install-laptop.sh (the flake app "install", README section 4.1) makes the copy, asks
# the questions, writes identity.json and runs this script:
#   bash <copy>/tools/install.sh thinkpad|thinkpad-vm
# It sets INSTALL_PASSWORD (the disk (LUKS) password and the password of the user) and INSTALL_YES=1
# (no "yes" question of disko). Without INSTALL_PASSWORD it asks for one password.
# First it updates flake.lock (the newest inputs), then disko and nixos-install use the copy.
set -euo pipefail

host=${1:?usage: install.sh <thinkpad|thinkpad-vm>}
work=$(cd "$(dirname "$0")/.." && pwd)
# The checkout path that home/default.nix links to (flake.nix: btopConfigCheckout).
case $host in thinkpad-vm) dest=nixos-config ;; *) dest=Work/nixos-config ;; esac
export NIX_CONFIG="experimental-features = nix-command flakes"
cd "$work"
user=$(nix eval --raw --impure --expr "(builtins.fromJSON (builtins.readFile $work/identity.json)).user")

pw=${INSTALL_PASSWORD:-}
while [ -z "$pw" ]; do
  read -rsp "Password (disk and user): " pw; echo
  read -rsp "Type it again: " pw2; echo
  [ -n "$pw" ] && [ "$pw" = "$pw2" ] && break
  pw=; echo "The passwords are not the same, or empty. Try again."
done
unset pw2 INSTALL_PASSWORD
install -m 600 /dev/null /tmp/disk-password
printf '%s' "$pw" > /tmp/disk-password
trap 'rm -f /tmp/disk-password' EXIT

echo "==> Updating the flake inputs"
nix flake update
echo "==> Partitioning and encrypting the disk"
nix run .#disko -- ${INSTALL_YES:+--yes-wipe-all-disks} --mode destroy,format,mount --flake ".#$host"
rm -f /tmp/disk-password

nixos-generate-config --no-filesystems --show-hardware-config > "hosts/$host/hardware-configuration.nix"
git add -A
echo "==> Installing the system"
nixos-install --no-root-passwd --flake ".#$host"
echo "==> Setting your password"
printf '%s:%s\n' "$user" "$pw" | nixos-enter --root /mnt -c chpasswd
unset pw

echo "==> Copying the configuration"
mkdir -p "/mnt/home/$user/$(dirname "$dest")"
cp -a "$work" "/mnt/home/$user/$dest"
nixos-enter --root /mnt -c "chown -R $user:users /home/$user/${dest%%/*}"
echo "Done. Run 'poweroff' and start the new system."
