# Desktop session: Hyprland (through uwsm), login, portals, keyring, fonts, input
# methods and the tools the Quickshell shell (home/shell) calls. User-level parts
# (Hyprland config, shell, lock/idle, theme) are in home/.
{ config, lib, pkgs, user, inputs, ... }:
{
  # omasnap and monologue as ordinary packages (pkgs/apps.nix).
  nixpkgs.overlays = [
    (final: prev:
      let
        apps = final.callPackage ../pkgs/apps.nix {
          sources = {
            omasnap = inputs.omasnap;
            monologue = inputs.monologue;
          };
        };
      in
      {
        inherit (apps) omasnap monologue;
        ttfx = final.callPackage ../pkgs/ttfx.nix { };
        plymouth-theme-omarchy = final.callPackage ../pkgs/plymouth-theme.nix { src = "${inputs.desktop-shell}/default/plymouth"; };
        # The bar and panels: upstream shell code plus four extra bar plugins (pkgs/desktop-shell.nix).
        desktop-shell = final.callPackage ../pkgs/desktop-shell.nix {
          src = inputs.desktop-shell;
          plugins = {
            "io.github.ajanraj.disposable-email" = inputs.plugin-disposable-email;
            "sviat.nightlight" = inputs.plugin-nightlight;
            "debba.media-control" = inputs.plugin-media-control;
          };
        };
      })
  ];

  programs.hyprland = { enable = true; withUWSM = true; };

  # The Hyprland config (home/hypr) loads the desktop-shell defaults from OMARCHY_PATH, which
  # also holds the omarchy-* helpers (default/hypr/envs.lua puts $OMARCHY_PATH/bin on
  # Hyprland's PATH). The upstream laptop setup sets the same variable in uwsm's env.d.
  # The session variables reach the uwsm session through PAM.
  environment.sessionVariables = {
    OMARCHY_PATH = "${pkgs.desktop-shell}/share/desktop-shell";
    TERMINAL = "xdg-terminal-exec"; # as in default/uwsm/default
  };

  # Login as on the upstream laptop setup: SDDM on Wayland, the greeter runs in Hyprland with the
  # desktop-shell greeter config, and the desktop-shell theme (both from the package). The disk unlock
  # already authenticates, so the user logs in automatically; after a log out SDDM asks for the password.
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "omarchy";
      settings.Wayland.CompositorCommand =
        "${lib.getExe' pkgs.hyprland "start-hyprland"} -- --config ${pkgs.desktop-shell}/share/desktop-shell/default/sddm/hyprland.lua";
    };
    autoLogin = { enable = true; inherit user; };
    defaultSession = "hyprland-uwsm";
  };

  # Log in only after Home Manager has written the user's config files.
  systemd.services.display-manager = {
    after = [ "home-manager-${user}.service" ];
    wants = [ "home-manager-${user}.service" ];
  };

  # The tools of the omarchy-* helpers and of the shell, on the session PATH.
  environment.systemPackages = pkgs.desktop-shell.runtimeTools ++ (with pkgs; [
    quickshell                                  # runs the picker and OSD (home/shell)
    desktop-shell                               # the bar and panels
    kitty                                       # default terminal (Super+Return)
    foot ghostty alacritty                      # other terminals (configs in home/config)
    hyprland-preview-share-picker               # screen share picker (config in home/config)
    omasnap monologue                           # screenshots (incl. scrolling), webcam recorder
    hyprpicker hyprsunset wl-clipboard cliphist grim slurp wtype
    brightnessctl playerctl pamixer ddcutil libnotify jq
    networkmanager bluez xdg-utils xdg-terminal-exec
    gtk3                                        # gtk-launch: the app menu starts apps with it (through uwsm-app)
    gpu-screen-recorder adwaita-icon-theme papirus-icon-theme
    udiskie                                     # started by the Hyprland defaults (default/hypr/autostart.lua)
  ]);
  xdg.terminal-exec = { enable = true; settings.default = [ "kitty.desktop" ]; };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # File dialogs: the first portal in the list that has a file chooser. Hyprland's own portal has
    # none yet (xdg-desktop-portal-hyprland PR 472 adds one); after its release and a flake update
    # it takes over by itself. Until then the GTK dialog is used. The GTK portal stays: it also gives
    # the Settings interface (dark mode) to apps.
    # This file replaces the default one of Hyprland, so it repeats its default order and the
    # keyring line of the current laptop.
    config.hyprland = {
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };
  };
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false; # gnome-keyring turns it on; the OpenSSH agent (home/default.nix) owns SSH_AUTH_SOCK
  security.pam.services.sddm.enableGnomeKeyring = true;
  # The shell's lock screen (Super+Ctrl+L, idle) checks the password and the fingerprint
  # through these two PAM services, read by name from /etc/pam.d.
  security.pam.services.omarchy-lock-password.fprintAuth = false;
  security.pam.services.omarchy-lock-fingerprint = { unixAuth = false; fprintAuth = true; };
  security.polkit.enable = true;
  programs.dconf.enable = true;
  programs.gpu-screen-recorder.enable = true; # screen recording with hardware encoding
  # Position for the weather panel. GeoClue uses the default provider of nixpkgs (BeaconDB,
  # from the nearby Wi-Fi networks). Only the where-am-i tool of home/location.nix may ask.
  services.geoclue2 = {
    enable = true;
    appConfig.geoclue-where-am-i = { isAllowed = true; isSystem = true; };
  };
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  # Boot splash. The initrd is systemd based (the only kind in this nixpkgs), so plymouth also
  # shows the disk password prompt.
  boot.plymouth = {
    enable = true;
    theme = "omarchy";
    themePackages = [ pkgs.plymouth-theme-omarchy ];
  };
  # Input methods: fcitx5 with the Wayland frontend. The profile has only keyboard-us. The keyboard
  # addon gives word completion (Ctrl+Alt+H turns it on and off, its default key). Superwhisper
  # brings its own fcitx5 addon to insert the dictated text. The settings are the defaults in
  # /etc/xdg/fcitx5; fcitx5 writes its own changes to ~/.config/fcitx5.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [ (pkgs.callPackage ../pkgs/superwhisper.nix { }) ];
      settings = {
        # Ctrl+Space is not a trigger key: the terminal multiplexer needs it. Super+I switches the
        # input language (the desktop shell binds it).
        globalOptions = {
          "Hotkey/TriggerKeys" = { "0" = "Zenkaku_Hankaku"; "1" = "Hangul"; };
          "Hotkey/ActivateKeys"."0" = "Henkan";
          "Hotkey/DeactivateKeys"."0" = "Muhenkan";
          "Hotkey/AltTriggerKeys"."0" = "Shift_L";
          "Hotkey/EnumerateGroupForwardKeys" = { };
          "Hotkey/EnumerateGroupBackwardKeys" = { };
          Behavior.ActiveByDefault = false;
        };
        inputMethod = {
          "Groups/0" = { Name = "Default"; "Default Layout" = "us"; DefaultIM = "keyboard-us"; };
          "Groups/0/Items/0".Name = "keyboard-us";
          GroupOrder."0" = "Default";
        };
        addons = {
          classicui = { globalSection = { Theme = "nord"; DarkTheme = "nord"; }; sections = { }; }; # theme: home/desktop.nix
          clipboard = { globalSection = { TriggerKey = ""; PastePrimaryKey = ""; }; sections = { }; };
          quickphrase = { globalSection = { }; sections.TriggerKey."0" = "Super+semicolon"; };
          wayland = { globalSection."Allow Overriding System XKB Settings" = false; sections = { }; };
          xcb = { globalSection."Allow Overriding System XKB Settings" = false; sections = { }; };
        };
      };
    };
  };
  # The desktop shell restarts fcitx5 by this unit name (bin/omarchy-restart-xcompose).
  # --replace takes the bus name from any other fcitx5; the shell draws its own tray item.
  systemd.user.services.omarchy-fcitx5 = {
    description = "Fcitx5 input methods and XCompose sequences";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      Type = "dbus";
      BusName = "org.fcitx.Fcitx5";
      ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5 --replace --disable notificationitem";
      Restart = "always";
      RestartSec = 2;
    };
  };
  services.logind.settings.Login.HandlePowerKey = "ignore"; # the power key opens the power menu

  # Caps Lock = Caps Lock, Shift+Caps Lock = Compose. libxkbcommon (used by
  # Hyprland) reads custom XKB rules from /etc/xkb. The option has the name of the upstream
  # laptop setup (omarchy:shift_caps_compose), which default/hypr/input.lua enables.
  environment.etc."xkb/rules/evdev".text = ''
    ! include %S/evdev

    ! option = symbols
      omarchy:shift_caps_compose = +omarchy(shift_caps_compose)
  '';
  environment.etc."xkb/symbols/omarchy".text = ''
    partial modifier_keys
    xkb_symbols "shift_caps_compose" {
      key <CAPS> {
        type[Group1] = "TWO_LEVEL",
        symbols[Group1] = [ Caps_Lock, Multi_key ],
        actions[Group1] = [ LockMods(modifiers = Lock), NoAction() ]
      };
    };
  '';

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono noto-fonts noto-fonts-cjk-sans noto-fonts-color-emoji font-awesome inter
      desktop-shell                             # the shell's own icon font (menu button, workspaces)
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Inter" "Noto Sans" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
