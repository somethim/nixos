# Test VM: the desktop without the laptop's disk layout or app set.
{ lib, modulesPath, user, ... }:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  networking.hostName = "desktop-vm";
  virtualisation = { memorySize = 6144; cores = 4; diskSize = 16384; resolution = { x = 1920; y = 1080; }; };
  # Hyprland needs a KMS GPU; virtio-gpu with Mesa's software renderer works in QEMU.
  virtualisation.qemu.options = [ "-vga none" "-device virtio-gpu-pci,xres=1920,yres=1080" ];
  # Self-contained store image, so the VM runs without host privileges.
  virtualisation.useNixStoreImage = true;
  virtualisation.mountHostNixStore = false;
  virtualisation.writableStore = true; # Home Manager registers its generation in the store
  virtualisation.sharedDirectories = lib.mkForce { };
  # Test logs: the journal goes to the serial port (tools/out/vm-serial.log).
  services.journald.settings.Journal = { ForwardToConsole = true; TTYPath = "/dev/ttyS0"; MaxLevelConsole = "info"; };
  users.users.${user}.initialPassword = "vm";
  system.stateVersion = "26.05";
}
