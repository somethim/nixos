{ identity, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = identity.hostName or "thinkpad";
  # The flake attribute of this host. The rebuild and update scripts read it, so a changed host
  # name (installer question) does not break them.
  environment.etc."nixos/flake-host".text = "thinkpad";
  services.btrfs.autoScrub.enable = true; # monthly integrity check of the btrfs disk

  # Charge limit thresholds for UPower (start,end). The bar switch "Limit charge to 80%"
  # turns the limit on or off (pkgs/desktop-shell-charge-limit.patch).
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="BAT*", ENV{CHARGE_LIMIT}="75,80"
  '';

  # Same layout as today: laptop panel left of the external screens.
  # Hyprland reads these from home/hypr/monitors.lua; nothing to do here.

  system.stateVersion = "26.05";
}
