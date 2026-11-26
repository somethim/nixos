# The desktop's user side: Hyprland config, the shells (bar and
# notifications from desktop-shell; picker from ./shell) and the services
# around them (wallpaper, sleep lock, night light, clipboard, polkit).
{ config, lib, pkgs, ... }:
let
  # Emoji list for the picker: [["😀", "grinning face"], ...] from Unicode's data.
  emojiJson = pkgs.runCommand "emoji.json" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 - ${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt > $out <<'EOF'
    import json, sys
    out = []
    for line in open(sys.argv[1], encoding="utf-8"):
        if "; fully-qualified" not in line or "#" not in line:
            continue
        _, _, rest = line.partition("#")
        parts = rest.strip().split(" ", 2)  # emoji, version, name
        if len(parts) == 3:
            out.append([parts[0], parts[2]])
    json.dump(out, sys.stdout, ensure_ascii=False)
    EOF
  '';

  # The picker's colours, from the one colour file (./theme/colors.toml).
  palette = pkgs.writeText "palette.json"
    (builtins.toJSON (import ./theme/palette.nix (builtins.fromTOML (builtins.readFile ./theme/colors.toml))));

  # The picker's config directory: QML from ./shell plus the palette and the emoji list.
  shellConfig = pkgs.runCommand "picker-shell" { } ''
    cp -r ${./shell} $out
    chmod -R u+w $out
    cp ${palette} $out/palette.json
    cp ${emojiJson} $out/emoji.json
  '';

  # Super+Alt+F: focused column full <-> half width (one state).
  # The menu actions (home/config/omarchy-menu.jsonc): rebuild, edit files of the checkout.
  nixosMenu = pkgs.writeShellApplication {
    name = "nixos-menu";
    runtimeInputs = with pkgs; [ git ];
    text = builtins.readFile ./scripts/nixos-menu;
  };

  focusWidth = pkgs.writeShellApplication {
    name = "hypr-focus-width";
    runtimeInputs = with pkgs; [ jq hyprland ];
    text = builtins.readFile ./scripts/hypr-focus-width;
  };

  # The bar, panels and notifications: the desktop-shell package (pkgs/desktop-shell.nix), started by Hyprland.
  # It keeps its own config in ~/.config/omarchy. The shell writes shell.json (bar layout), so
  # that file is linked to the checkout, like the other writable configs in default.nix.
  shellPkg = pkgs.desktop-shell;
  superwhisper = pkgs.callPackage ../pkgs/superwhisper.nix { };
  shellShare = "${shellPkg}/share/desktop-shell";
  extraPlugins = [
    "io.github.ajanraj.disposable-email" "sviat.nightlight" "debba.media-control"
  ];
  localPlugins = builtins.attrNames (builtins.readDir ./shell-plugins);

  # The nord theme, rendered at build time by the packaged upstream scripts: the templates
  # (default/themed/*.tpl) are filled from ./theme/colors.toml (the menu Appearance > Colours opens it),
  # then the glass step adds the
  # see-through terminal background (opacity 0.65) that the window-glassy toggle turns on.
  # Apps include these files from ~/.local/state/omarchy/current/theme.
  nordTheme = pkgs.runCommand "theme-nord"
    {
      nativeBuildInputs = shellPkg.runtimeTools;
    } ''
    export HOME=$TMPDIR/home XDG_STATE_HOME=$TMPDIR/home/.local/state
    export OMARCHY_PATH=${shellShare} PATH=${shellShare}/bin:$PATH
    next=$HOME/.local/state/omarchy/current/next-theme
    mkdir -p $next $XDG_STATE_HOME/omarchy/toggles/hypr
    cp -r ${shellShare}/themes/nord/. $next/
    chmod -R u+w $next
    cp ${./theme/colors.toml} $next/colors.toml
    # The glass step reads the window-glassy toggle (the one that hyprToggles installs below).
    cp ${./hypr-state/toggles/window-glassy.lua} $XDG_STATE_HOME/omarchy/toggles/hypr/window-glassy.lua
    omarchy-theme-set-templates
    cp -r $next $out
  '';
in
{
  # Hyprland: the Lua overrides from ./hypr, loaded on top of the packaged defaults (OMARCHY_PATH, modules/desktop.nix).
  xdg.configFile = lib.mapAttrs' (name: _: lib.nameValuePair "hypr/${name}" { source = ./hypr + "/${name}"; })
    (builtins.readDir ./hypr)
  // lib.listToAttrs (map (id: lib.nameValuePair "omarchy/plugins/${id}" { source = "${shellShare}/plugins/${id}"; }) extraPlugins)
  // {
    "btop/themes/current.theme".source = "${nordTheme}/btop.theme";
    # The user unit omarchy-fcitx5 (modules/desktop.nix) starts fcitx5, so hide the stock autostart entry (XDG: Hidden=true).
    "autostart/org.fcitx.Fcitx5.desktop".text = "[Desktop Entry]\nHidden=true\n";
    # Menu rows for NixOS: they replace or hide the rows of the packaged menu that need Arch Linux.
    # The shell only reads this file.
    "omarchy/extensions/omarchy-menu.jsonc".source = ./config/omarchy-menu.jsonc;
    "omarchy/plugins/superwhisper.panel".source =
      "${superwhisper}/lib/superwhisper/assets/omarchy-plugin/superwhisper-panel";
  }
  // lib.listToAttrs (map (id: lib.nameValuePair "omarchy/plugins/${id}" { source = ./shell-plugins + "/${id}"; }) localPlugins);

  # The fcitx5 theme (classicui in modules/desktop.nix): the rendered nord theme and the default images.
  xdg.dataFile = lib.listToAttrs (map (f: lib.nameValuePair "fcitx5/themes/nord/${f}.svg"
    { source = "${pkgs.fcitx5}/share/fcitx5/themes/default/${f}.svg"; }) [ "arrow" "next" "prev" "radio" ])
  // { "fcitx5/themes/nord/theme.conf".source = "${nordTheme}/fcitx5-theme.conf"; };

  # shell.json (bar layout) is written by the shell. With a checkout it is a link to the repo
  # file; this replaces the default file the shell writes on its first start. Without the checkout (a fresh install, the VM), a dangling link would
  # give the shell its default bar, so a writable copy of the repo file is seeded instead.
  home.activation.shellJson = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    target="$HOME/.config/omarchy/shell.json"
    # The checkout is ~/Work/nixos-config on the laptop and ~/nixos-config in the test VM.
    repo=""
    for c in "$HOME/Work/nixos-config" "$HOME/nixos-config"; do
      if [ -e "$c/home/config/shell.json" ]; then repo="$c/home/config/shell.json"; break; fi
    done
    run mkdir -p "$HOME/.config/omarchy"
    if [ -n "$repo" ]; then
      run ln -sfn "$repo" "$target"
    elif [ ! -e "$target" ]; then
      run rm -f "$target"
      run install -m644 ${./config/shell.json} "$target"
    fi
  '';

  # The wallpaper. The shell draws it itself (it replaces hyprpaper). The menu (Appearance >
  # Background) changes the link, so a first value is only set when there is none.
  home.activation.wallpaper = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    target="$HOME/.local/state/omarchy/current/background"
    if [ ! -e "$target" ]; then
      run mkdir -p "$(dirname "$target")"
      run ln -sfn ${./wallpaper.jpg} "$target"
    fi
  '';

  # The theme the shell and the apps read (colours): the rendered nord theme. btop finds it as
  # themes/current.theme (color_theme = "current").
  xdg.stateFile = {
    "omarchy/current/theme".source = nordTheme;
    "omarchy/current/theme.name".text = "nord";
    # First-run marker. The upstream first-run step (omarchy-provision-first-run, started by the
    # Hyprland defaults) skips everything when this file exists. Its steps are Arch-only or are set
    # by this configuration (GTK theme and dconf in home/theme.nix, user services by NixOS), so on
    # NixOS it only prints errors and welcome notices. `omarchy-done check` tests with `-f`, which follows links.
    "omarchy/done/first-run-user".text = "";
  };

  # Appearance toggles that are on (glassy bar and windows, rounded corners): the files that
  # the toggles of the desktop shell write to this directory. The Hyprland defaults load all of them, but
  # find them with `find -type f` (default/hypr/require_all.lua), which skips symlinks. So they
  # are copied as regular files and not linked like the other state files.
  # A manifest ($dir/.nix-managed) lists the copies this hook made, so a copy whose source was
  # removed is deleted too. Files that the shell or the user wrote are not in the manifest.
  home.activation.hyprToggles = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    dir="''${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr"
    manifest="$dir/.nix-managed"
    run mkdir -p "$dir"
    if [ -f "$manifest" ]; then
      while IFS= read -r name; do
        [ -n "$name" ] && [ ! -e "${./hypr-state/toggles}/$name" ] && run rm -f -- "$dir/$name"
      done < "$manifest"
    fi
    : > "$manifest.new"
    for f in ${./hypr-state/toggles}/*.lua; do
      run install -m644 "$f" "$dir/$(basename "$f")"
      basename "$f" >> "$manifest.new"
    done
    run mv -f "$manifest.new" "$manifest"
  '';

  # The shell is not a service: the packaged defaults of the Hyprland config start it
  # (omarchy-launch-shell, default/hypr/autostart.lua). Its tools come from the session PATH (modules/desktop.nix).

  programs.quickshell = {
    enable = true;
    configs.desktop = shellConfig;
    activeConfig = "desktop";
    systemd.enable = true;
  };

  systemd.user.services.superwhisper = {
    Unit = {
      Description = "Superwhisper dictation";
      After = [ "wayland-session-waitenv.service" "pipewire.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe superwhisper} daemon";
      ExecStopPost = "${lib.getExe superwhisper} playback-restore";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 15;
      UMask = "0077";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = [ focusWidth nixosMenu superwhisper ] ++ (with pkgs; [
    wiremix bluetui gnome-calculator tesseract
  ]);



  # Idle and lock belong to the shell only: its idle service locks after 300 s unless the
  # stay-awake marker exists. This unit makes the shell lock before suspend (the upstream
  # omarchy-sleep-lock.service): the monitor holds a sleep inhibitor, and on PrepareForSleep it
  # calls omarchy-system-sleep-lock.
  systemd.user.services.sleep-lock = {
    Unit = {
      Description = "Lock the shell before suspend";
      After = [ "wayland-session-waitenv.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${shellShare}/bin/omarchy-system-sleep-monitor";
      Environment = [
        "OMARCHY_PATH=${shellShare}"
        "PATH=${lib.makeBinPath (shellPkg.runtimeTools ++ [ pkgs.dbus ])}:${shellShare}/bin"
      ];
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Night light: the bar's nightlight plugin writes hyprsunset's config and restarts this unit.
  services.hyprsunset.enable = true;

  services.cliphist.enable = true;        # clipboard history for the picker (Super+Ctrl+V)
}
