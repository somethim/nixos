# Placeholder for the VM. The installation replaces it with the output of
# `nixos-generate-config --no-filesystems --show-hardware-config` (README, section 9).
{ ... }:
{
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" "ahci" "xhci_pci" "sr_mod" ];
  boot.kernelModules = [ "kvm-amd" ];
  nixpkgs.hostPlatform = "x86_64-linux";
}
