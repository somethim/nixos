{
  description = "ThinkPad: NixOS with a Hyprland + Quickshell desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Upstream sources of the desktop packages. They follow each project's default branch;
    # flake.lock pins the exact commit. `nix flake update <name>` moves one to the newest commit.
    omasnap = { url = "github:omacom/omasnap"; flake = false; };
    monologue = { url = "github:omacom/monologue"; flake = false; };
    desktop-shell = { url = "github:omacom/omarchy"; flake = false; };
    plugin-disposable-email = { url = "github:ajanraj/omarchy-disposable-email"; flake = false; };
    plugin-media-control = { url = "github:debba/omarchy-media-control"; flake = false; };
    plugin-nightlight = { url = "github:devSviat/omarchy-nightlight"; flake = false; };
    omazed = { url = "github:aps6/omazed"; flake = false; };
    llama-cpp = { url = "github:ggml-org/llama.cpp"; flake = false; };
    # The agent skills (own and third-party), a public repository.
    agent-skills = { url = "github:somethim-omarchy/agent-skills"; flake = false; };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, disko, ... }:
    let
      # The values of the person who installs. the installer (tools/install-laptop.sh) writes this file at install time.
      identity = builtins.fromJSON (builtins.readFile ./identity.json);
      user = identity.user;
      system = "x86_64-linux";
      specialArgs = { inherit user identity inputs; };
      desktop = btopConfigCheckout: [
        ./modules/system.nix
        ./modules/desktop.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "pre-hm";
            extraSpecialArgs = specialArgs // { inherit btopConfigCheckout; };
            users.${user} = import ./home;
          };
        }
      ];
    in
    {
      nixosConfigurations.thinkpad = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = desktop "Work/nixos-config" ++ [
          disko.nixosModules.disko
          ./hosts/thinkpad
          ./modules/apps.nix
          ./modules/dev.nix
          ./modules/npu.nix
          ./modules/robotics.nix
          ./modules/security.nix
          { home-manager.users.${user}.imports = [ ./home/local-ai.nix ]; }
        ];
      };

      # The full laptop system installed in a VM (tools/vm-install.sh).
      nixosConfigurations.thinkpad-vm = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = desktop "nixos-config" ++ [
          disko.nixosModules.disko
          ./hosts/thinkpad-vm
          ./modules/apps.nix
          ./modules/dev.nix
          ./modules/robotics.nix
          ./modules/security.nix
        ];
      };

      # The desktop alone (no apps or toolchains) in a test VM:
      #   nix build .#nixosConfigurations.vm.config.system.build.vm && ./result/bin/run-desktop-vm-vm
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = desktop null ++ [ ./hosts/vm.nix ];
      };

      # The installer: `nix run github:somethim/nixos#install` in the official NixOS minimal ISO
      # (README 4.1). It runs tools/install-laptop.sh on a writable copy of this flake (self).
      apps.${system}.install =
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          # The one colour file of the desktop. The installer uses the same Nord colours.
          c = builtins.fromTOML (builtins.readFile ./home/theme/colors.toml);
          # The prefix of the install-laptop script: colours, gum colours, tools, and data lists.
          prefix = ''
            NORD_BG=${c.background} NORD_FG=${c.foreground} NORD_MUTED=${c.muted} NORD_SELECT=${c.selection}
            NORD_RED=${c.red} NORD_GREEN=${c.green} NORD_YELLOW=${c.yellow} NORD_ACCENT=${c.accent}
            NORD_BLUE=${c.blue} NORD_CYAN=${c.cyan} NORD_CYAN2=${c.bright_cyan} NORD_MAGENTA=${c.magenta}
            # The text console has 16 colours: use their numbers.
            if [ "''${TERM:-}" = linux ]; then
              NORD_BG=0 NORD_FG=7 NORD_MUTED=8 NORD_SELECT=8 NORD_RED=1 NORD_GREEN=2 NORD_YELLOW=3
              NORD_ACCENT=4 NORD_BLUE=4 NORD_CYAN=6 NORD_CYAN2=14 NORD_MAGENTA=5
            fi
            export NORD_FG NORD_RED NORD_GREEN NORD_YELLOW NORD_BLUE NORD_CYAN NORD_CYAN2 NORD_MAGENTA
            export GUM_INPUT_CURSOR_FOREGROUND=$NORD_ACCENT GUM_INPUT_PROMPT_FOREGROUND=$NORD_ACCENT
            export GUM_INPUT_HEADER_FOREGROUND=$NORD_CYAN GUM_INPUT_PLACEHOLDER_FOREGROUND=$NORD_MUTED
            export GUM_CONFIRM_PROMPT_FOREGROUND=$NORD_FG
            export GUM_CONFIRM_SELECTED_BACKGROUND=$NORD_GREEN GUM_CONFIRM_SELECTED_FOREGROUND=$NORD_BG
            export GUM_CONFIRM_UNSELECTED_BACKGROUND=$NORD_SELECT GUM_CONFIRM_UNSELECTED_FOREGROUND=$NORD_FG
            export GUM_CHOOSE_CURSOR_FOREGROUND=$NORD_ACCENT GUM_CHOOSE_HEADER_FOREGROUND=$NORD_CYAN
            export GUM_CHOOSE_SELECTED_FOREGROUND=$NORD_CYAN GUM_CHOOSE_ITEM_FOREGROUND=$NORD_FG
            export GUM_FILTER_INDICATOR_FOREGROUND=$NORD_ACCENT GUM_FILTER_MATCH_FOREGROUND=$NORD_CYAN
            export GUM_FILTER_HEADER_FOREGROUND=$NORD_CYAN GUM_FILTER_PROMPT_FOREGROUND=$NORD_ACCENT
            export GUM_FILTER_TEXT_FOREGROUND=$NORD_FG GUM_FILTER_PLACEHOLDER_FOREGROUND=$NORD_MUTED
            export GUM_INPUT_PADDING="0 0 0 4" GUM_CONFIRM_PADDING="0 0 0 4" GUM_CHOOSE_PADDING="0 0 0 4" GUM_FILTER_PADDING="0 0 0 4"
            export GUM_SPIN_SPINNER_FOREGROUND=$NORD_ACCENT GUM_SPIN_TITLE_FOREGROUND=$NORD_FG
            export PATH=${lib.makeBinPath [ pkgs.gum pkgs.jq pkgs.gawk pkgs.git ]}:$PATH
            export SRC=${self}
            export LOGO=${./home/config/branding/installer-logo.txt}
            export ZONE_TAB=${pkgs.tzdata}/share/zoneinfo/zone.tab
            export XKB_LST=${pkgs.xkeyboard-config}/share/X11/xkb/rules/evdev.lst
          '';
          install = pkgs.writeShellScriptBin "install" (prefix + builtins.readFile ./tools/install-laptop.sh);
        in
        { type = "app"; program = "${install}/bin/install"; };

      packages.${system} = {
        inherit (self.nixosConfigurations.thinkpad.pkgs) omasnap monologue desktop-shell ttfx;
        # tools/install.sh runs it (`nix run .#disko`).
        inherit (disko.packages.${system}) disko;
      };
    };
}
