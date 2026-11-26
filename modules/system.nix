# Machine-level services: boot, network, hardware, containers, users.
{ pkgs, user, identity, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" user ];
    auto-optimise-store = true;
  };
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 21d"; };
  nixpkgs.config.allowUnfree = true;

  # Every rebuild is a boot entry, so a bad update is one reboot from undone
  # (what Limine + Snapper did on Arch).
  boot = {
    loader.systemd-boot = { enable = true; configurationLimit = 20; };
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest; # Krackan GPU + amdxdna NPU need a recent kernel
    kernelParams = [ "quiet" "splash" ];
  };
  zramSwap = { enable = true; memoryPercent = 100; };
  systemd.oomd.enable = true;

  time.timeZone = identity.timeZone;
  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.xkb.layout = identity.keyboard;
  console.useXkbConfig = true; # the text console uses the same layout
  environment.sessionVariables.XKB_DEFAULT_LAYOUT = identity.keyboard; # Hyprland reads it

  networking.networkmanager = {
    enable = true; # firewall, SSH, Tailscale: see security.nix
    # Random Wi-Fi address that stays the same on each network; wired keeps the hardware address.
    wifi = { macAddress = "stable"; scanRandMacAddress = true; };
    ethernet.macAddress = "permanent";
  };
  services.resolved.enable = true;
  services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };
  services.printing = { enable = true; drivers = [ pkgs.splix ]; };

  hardware.bluetooth = { enable = true; powerOnBoot = true; };
  hardware.graphics = { enable = true; enable32Bit = true; };
  hardware.enableRedistributableFirmware = true;
  hardware.i2c.enable = true; # ddcutil: external monitor brightness
  services.fprintd.enable = true; # fingerprint for sudo, polkit (1Password) and the lock screen
  services.fwupd.enable = true;
  services.hardware.bolt.enable = true;
  services.locate.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = { enable = true; support32Bit = true; };
    pulse.enable = true;
  };

  # Docker and Podman side by side (podman's docker alias stays off so `docker` is Docker).
  virtualisation.docker.enable = true;
  # A published port with no host address binds to 127.0.0.1 (not the LAN) on the default bridge.
  virtualisation.docker.daemon.settings.ip = "127.0.0.1";
  virtualisation.podman = { enable = true; defaultNetwork.settings.dns_enabled = true; };


  users.users.${user} = {
    isNormalUser = true;
    description = identity.fullName;
    extraGroups = [ "wheel" "networkmanager" "docker" "podman" "video" "input" "i2c" "lp" ];
  };
}
