# Network security, remote access, phone sharing and malware scanning.
{ pkgs, user, ... }:
let
  home = "/home/${user}";
  # High-churn folders that would turn every build, update or game download
  # into thousands of scans. They're still covered by the weekly full scan
  # unless also listed in skipInFullScan.
  skipOnAccess = map (d: "${home}/${d}") [
    ".cache" ".local/share/Steam" ".steam" "Games" ".local/share/heroic"
    ".local/share/containers" ".local/share/docker" ".local/share/mise" ".local/share/zoxide"
    ".cargo" ".rustup" "go" ".npm" ".bun" ".pnpm-store" ".gradle" ".m2" ".android" "Android"
    ".local/state" ".mozilla" ".config/chromium" ".config/BraveSoftware"
    ".config/Slack" ".config/discord" "Work" "Projects"
  ];
  # Regexes clamd skips during the weekly full scan: build output, dependency
  # trees, git objects, caches and game libraries.
  skipInFullScan = [
    "/node_modules/" "/target/" "/\\.git/objects/" "/\\.cache/" "/\\.local/share/Steam/"
    "/Games/" "/\\.local/share/containers/" "/\\.rustup/" "/\\.cargo/registry/" "/go/pkg/"
  ];
in
{
  # Firewall: deny inbound by default. Tailscale is trusted, so SSH and Taildrop
  # work from your own devices only; LAN ports open only where a feature needs them
  # (LocalSend, Steam Remote Play, mDNS).
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    logRefusedConnections = false;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client"; # use exit nodes / subnet routes (sets reverse-path filtering correctly)
    extraSetFlags = [ "--operator=${user}" ]; # lets your user receive Taildrop files without root
  };
  systemd.user.services.taildrop-receive = {
    description = "Receive Taildrop files into ~/Downloads";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.tailscale}/bin/tailscale file get --wait --loop --conflict=rename %h/Downloads";
      Restart = "on-failure";
      RestartSec = 30;
    };
  };

  # SSH: keys only, no root, reachable through Tailscale (port not opened on Wi-Fi/LAN).
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Captive portals (hotel/airport Wi-Fi): NetworkManager's connectivity check
  # against GNOME's endpoint (plain HTTP so a portal can intercept it). When it
  # reports a portal, the bar's network widget shows "Sign in" and opens the page.
  networking.networkmanager.settings.connectivity = {
    uri = "http://nmcheck.gnome.org/check_network_status.txt";
    response = "NetworkManager is online";
    interval = 300;
  };

  # Phone <-> laptop, AirDrop-style:
  # - LocalSend: send files and text to the laptop on the same network (port 53317).
  # - Taildrop: share via the Tailscale app from anywhere; files land in ~/Downloads
  #   (taildrop-receive below).
  programs.localsend = { enable = true; openFirewall = true; }; # opens 53317 TCP/UDP

  # ClamAV: signatures kept current; everything in home scanned as files are written
  # (minus the high-churn folders above); a daily quick scan; a weekly full scan of
  # home. Detections are logged: journalctl -u clamav-clamonacc -u clamdscan
  # -u clamav-weekly-home | grep FOUND. The daemon holds about 1 GB of RAM.
  services.clamav = {
    updater.enable = true;
    fangfrisch.enable = true; # extra community signatures (phishing, malware URLs)
    daemon = {
      enable = true;
      settings = {
        OnAccessIncludePath = [ home ];
        OnAccessExcludePath = skipOnAccess;
        OnAccessExcludeUname = "clamav";
        OnAccessMaxFileSize = "100M";
        ExcludePath = skipInFullScan;
        OnAccessPrevention = false; # alert, don't block (blocking can hang apps mid-download)
        OnAccessExtraScanning = true;
        MaxThreads = 4;
      };
    };
    clamonacc.enable = true;
    scanner = {
      enable = true;
      interval = "*-*-* 13:00:00"; # midday, when the laptop is usually on
      scanDirectories = [ "${home}/Downloads" "${home}/Desktop" "${home}/Documents" "/tmp" "/var/tmp" ];
    };
  };
  systemd.timers.clamdscan.timerConfig.Persistent = true; # run after boot if a scan was missed

  systemd.services.clamav-weekly-home = {
    description = "Weekly ClamAV scan of the home directory";
    after = [ "clamav-daemon.service" ];
    requires = [ "clamav-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.clamav}/bin/clamdscan --multiscan --fdpass --infected --allmatch ${home}";
      SuccessExitStatus = [ 1 ]; # 1 = something was found (reported below), not a failure
    };
  };
  systemd.timers.clamav-weekly-home = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "Sun 14:00"; Persistent = true; };
  };

  environment.systemPackages = [ pkgs.clamav ];
}
