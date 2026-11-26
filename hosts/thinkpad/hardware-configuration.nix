# Placeholder matching this ThinkPad (Ryzen AI 7 PRO 350, Radeon 860M).
# During install, replace it with the output of:
#   nixos-generate-config --no-filesystems --show-hardware-config
# File systems come from disko.nix, so the generated file must not define them.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = true;
}
