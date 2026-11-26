# Your user environment, declared with Home Manager.
#
# Config files come from ./config. Files that an app writes back to (btop on
# exit, Zed's settings UI, LazyVim's lock file) are linked
# to the checkout at ~/Work/nixos-config with mkOutOfStoreSymlink, so those
# changes land in the repo. All other files are read-only from the Nix store.
{ config, lib, pkgs, user, identity, btopConfigCheckout, ... }:
let
  cfg = ./config;
  checkout = if btopConfigCheckout == null then "Work/nixos-config" else btopConfigCheckout;
  repo = "${config.home.homeDirectory}/${checkout}/home/config";
  writable = path: config.lib.file.mkOutOfStoreSymlink "${repo}/${path}";

  email = identity.email;
  # Git signs commits with the public key file of the SSH key in ~/.ssh (README 4.3).
  # Set signCommits to true when the key exists.
  signCommits = false;
  signingKeyFile = "~/.ssh/id_ed25519.pub";

  # Chat and gaming apps start minimized to the tray at login.
  autostart = name: exec: pkgs.makeDesktopItem {
    inherit name exec;
    desktopName = name;
    extraConfig."X-GNOME-Autostart-enabled" = "true";
  };
in
{
  imports = [ ./desktop.nix ./theme.nix ./cli.nix ./calendar.nix ./agents.nix ./location.nix ./updates.nix ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = "26.05";
    # The packaged sequences first, then the personal ones of the checkout (home/XCompose, editable
    # from the menu, read at once). libxkbcommon and fcitx5 follow nested includes.
    file.".XCompose".text = ''
      include "${pkgs.desktop-shell}/share/desktop-shell/default/xcompose"
      include "${config.home.homeDirectory}/${checkout}/home/XCompose"
    '';
  };

  xdg.configFile = {
    # Written back by the app: linked to the repo checkout.
    "btop/btop.conf".source =
      if btopConfigCheckout == null then ./config/btop/btop.conf
      else config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/${btopConfigCheckout}/home/config/btop/btop.conf";
    "zed/settings.json".source = writable "zed/settings.json";
    "nvim".source = writable "nvim";
    # Read-only from the store. Their colours are included from the rendered theme (desktop.nix).
    "kitty/kitty.conf".source = "${cfg}/kitty/kitty.conf";
    "foot/foot.ini".source = "${cfg}/foot/foot.ini";
    "ghostty/config".source = "${cfg}/ghostty/config";
    "alacritty/alacritty.toml".source = "${cfg}/alacritty/alacritty.toml";
    "tmux".source = "${cfg}/tmux";
    "lazygit".source = "${cfg}/lazygit";
    "herdr/config.toml".source = "${cfg}/herdr/config.toml";
    "opencode" = { source = "${cfg}/opencode"; recursive = true; };
    "wireplumber".source = "${cfg}/wireplumber";
    "xdg-desktop-portal".source = "${cfg}/xdg-desktop-portal";
    "hyprland-preview-share-picker/config.yaml".source = "${cfg}/hyprland-preview-share-picker/config.yaml";
    "starship.toml".source = "${cfg}/starship.toml";
  };

  # Per-project toolchains: `use flake` in a repo's .envrc loads its devShell.
  programs.direnv = { enable = true; nix-direnv.enable = true; };

  programs.git = {
    enable = true;
    settings = {
      user = { name = identity.fullName; inherit email; };
      alias = { co = "checkout"; br = "branch"; ci = "commit"; st = "status"; };
      init.defaultBranch = "master";
      pull.rebase = true;
      push = { autoSetupRemote = true; followTags = true; };
      diff = { algorithm = "histogram"; colorMoved = "plain"; mnemonicPrefix = true; };
      commit.verbose = true;
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "-version:refname";
      rerere = { enabled = true; autoupdate = true; };
      gpg.ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
    };
    signing = {
      format = "ssh";
      key = signingKeyFile;
      signByDefault = signCommits;
    };
  };
  # allowed_signers holds the public key, which is outside this repository: write it from the key file.
  # Login keyring without its own password, as on the live host (SDDM logs in without a password,
  # so no password can unlock it). The disk encryption protects it. Written only when no keyring
  # exists, so an existing or restored keyring is never changed.
  home.activation.defaultKeyring = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dir="$HOME/.local/share/keyrings"
    if [ ! -e "$dir/default" ] && ! ls "$dir"/*.keyring >/dev/null 2>&1; then
      run mkdir -p "$dir"
      run chmod 700 "$dir"
      if [ -z "''${DRY_RUN:-}" ]; then
        umask 077
        printf '[keyring]\ndisplay-name=Default keyring\nctime=%s\nmtime=0\nlock-on-idle=false\nlock-after=false\n' "$(date +%s)" > "$dir/Default_keyring.keyring"
        printf 'Default_keyring\n' > "$dir/default"
      fi
    fi
  '';

  home.activation.allowedSigners = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    key="$HOME/.ssh/id_ed25519.pub"
    if [ -r "$key" ]; then
      run mkdir -p "${config.xdg.configHome}/git"
      run sh -c 'printf "%s %s\n" "$1" "$(cat "$2")" > "$3"' sh ${lib.escapeShellArg email} "$key" "${config.xdg.configHome}/git/allowed_signers"
    fi
  '';
  programs.gh = { enable = true; gitCredentialHelper.enable = true; };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".AddKeysToAgent = "yes";
  };
  # The standard OpenSSH agent. It sets SSH_AUTH_SOCK to $XDG_RUNTIME_DIR/ssh-agent in shells.
  services.ssh-agent.enable = true;

  xdg.autostart = {
    enable = true;
    entries = map (item: "${item}/share/applications/${item.name}") [
      (autostart "1Password" "1password --silent")
      (autostart "Steam" "steam -silent")
      (autostart "Discord" "discord --start-minimized")
      (autostart "Heroic" "heroic --no-gui")   # starts hidden in the tray
      (autostart "ZapZap" "zapzap --hideStart")   # starts hidden in the tray
    ];
  };

  # GTK file dialogs and Nautilus sidebar.
  gtk.gtk3.bookmarks = map (name: "file://${config.home.homeDirectory}/${name} ${name}")
    [ "Downloads" "Documents" "Projects" "Pictures" "Videos" "Work" "Portfolio" "Career" "Learning" ];

  # The standard folders (Documents, Downloads, Music, Pictures, Videos) and the empty work folders.
  xdg.userDirs = { enable = true; createDirectories = true; desktop = null; publicShare = null; templates = null; };

  # Games, saves and Wine prefixes stay outside the repository.
  systemd.user.tmpfiles.rules = [
    "d %h/Work 0755 - - -"
    "d %h/Projects 0755 - - -"
    "d %h/Learning 0755 - - -"
    "d %h/Portfolio 0755 - - -"
    "d %h/Career 0755 - - -"
    "d %h/Games 0755 - - -"
    "d /tmp/claude-%U 0700 - - -" # lock directory of the heavy-job rule (flock does not create it)
  ];

  # Taskwarrior starts without a question when this file exists. Add settings here.
  home.file.".taskrc".text = "# Taskwarrior user configuration.\n";

  # Missing Manual as an app window (Chromium --app), like the Claude and ChatGPT windows.
  xdg.dataFile."icons/hicolor/256x256/apps/missing-manual.png".source = ./config/icons/missing-manual.png;
  xdg.desktopEntries.missing-manual = {
    name = "Missing Manual";
    exec = "chromium --app=https://themissingmanual.dev/";
    icon = "missing-manual";
    categories = [ "Network" ];
    settings.StartupWMClass = "chrome-themissingmanual.dev__-Default";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-origin.desktop";
      "x-scheme-handler/http" = "brave-origin.desktop";
      "x-scheme-handler/https" = "brave-origin.desktop";
      "x-scheme-handler/mailto" = "thunderbird.desktop";
      "application/pdf" = "org.gnome.Papers.desktop";
      "image/png" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "video/mp4" = "mpv.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "text/markdown" = "typora.desktop";
      "text/x-markdown" = "typora.desktop";
    };
  };

  programs.home-manager.enable = true;
}
