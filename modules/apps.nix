# Apps. Add or remove one here, then run `sudo nixos-rebuild switch --flake ~/Work/nixos-config`.
{ pkgs, user, ... }:
let
  # Force-installed in Chromium and Brave Origin.
  extensions = [
    "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
    "fcoeoabgfenejglbffodgkkbkcdhcgfn" # Claude in Chrome
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "bkdgflcldnnnapblkhphbgpggdiikppg" # DuckDuckGo
    "mafpmfcccpbjnhfhjnllmmalhifmlcie" # Snowflake
    "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
  ];
in
{
  programs.steam = { enable = true; remotePlay.openFirewall = true; };
  programs.gamemode.enable = true;
  programs._1password.enable = true;
  programs._1password-gui = { enable = true; polkitPolicyOwners = [ user ]; };

  # Brave Origin (Brave without Rewards, Wallet, VPN and AI, free on Linux; select "Proceed with
  # Origin for free" at the first start) is the default browser (home/default.nix, xdg.mimeApps).
  # It reads the managed policies in /etc/brave/policies.
  programs.brave = {
    enable = true;
    package = pkgs.brave-origin;
    inherit extensions;
  };

  programs.chromium = { enable = true; inherit extensions; };

  environment.systemPackages = with pkgs; [
    # Communication (start at login: home/default.nix, home/hypr/autostart.lua)
    thunderbird zoho-mail-desktop zapzap wechat discord slack
    # Browsers (Brave Origin: programs.brave above; Ladybird: the nixpkgs build, prebuilt in cache.nixos.org)
    chromium tor-browser ladybird
    # Media
    spotify mpv imv papers calibre
    # Games
    heroic (retroarch.withCores (c: [ c.melonds c.mgba ]))
    wineWow64Packages.waylandFull winetricks unrar rsync # Wine (64-bit, Wayland); unrar is unfree (allowUnfree is on)
    # Creative / editors
    blender typora zed-editor android-studio
    # Files and system
    nautilus sushi baobab gnome-disk-utility system-config-printer anydesk
  ];

  # Cisco Packet Tracer 9: its setup (~/pt) is not in this repository. To install,
  # add the .deb to the store and uncomment:
  #   nix-store --add-file CiscoPacketTracer_901_Ubuntu_64bit.deb
  # environment.systemPackages = [ pkgs.ciscoPacketTracer9 ];
}
