# The full laptop system in a QEMU/KVM virtual machine, to test it before the real
# installation: same modules and disk layout (LUKS + btrfs), on the virtual disk /dev/vda.
# Start it with tools/vm-install.sh (see README, section 9).
{ lib, modulesPath, identity, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
    ../thinkpad/disko.nix
  ];

  disko.devices.disk.main.device = lib.mkForce "/dev/vda";
  networking.hostName = identity.hostName or "thinkpad-vm";
  # The flake attribute of this host. The rebuild and update scripts read it, so a changed host
  # name (installer question) does not break them.
  environment.etc."nixos/flake-host".text = "thinkpad-vm";

  # The host repository (tools/vm-install.sh shares it read-only as "config").
  fileSystems."/mnt/config" = {
    device = "config";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "ro" "nofail" ];
  };
  services.btrfs.autoScrub.enable = true;

  # Test host only: the serial console (last console= is /dev/console) asks the disk password and
  # shows the journal, so tools/vm-install-test.sh can drive and check the boot without a screen.
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" ];
  services.journald.settings.Journal = { ForwardToConsole = true; TTYPath = "/dev/ttyS0"; MaxLevelConsole = "info"; };

  system.stateVersion = "26.05";
}
