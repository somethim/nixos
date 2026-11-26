# Languages with their tooling (compiler/runtime, package manager, LSP, formatter,
# debugger), containers, Kubernetes, infrastructure and cloud CLIs, all from nixpkgs.
# Per-project toolchains: a flake devShell in the repo, loaded by direnv (home/default.nix).
{ config, lib, pkgs, ... }:
let
  # PHP with the extensions Laravel/Sail projects use, as its own package
  # (php for every other package stays the cached default).
  php = pkgs.php.buildEnv {
    extensions = { enabled, all }: enabled ++ (with all; [ redis xdebug imagick pcov ]);
    extraConfig = "memory_limit = 2G";
  };
in
{
  # One system Python; modules add libraries to it through python.packages.
  options.python.packages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "python3Packages attribute names for the single system Python.";
  };

  config = {
    python.packages = [ "debugpy" "pip" "virtualenv" ];

    environment.systemPackages = with pkgs; [
      # Python
      (python3.withPackages (ps: map (n: ps.${n}) config.python.packages))
      uv ruff basedpyright
      # PHP
      php php.packages.composer phpactor intelephense
      # TypeScript / JavaScript
      nodejs pnpm bun deno typescript vtsls vscode-langservers-extracted tailwindcss-language-server prettierd eslint_d
      # Rust (rustup manages toolchains, rust-analyzer, clippy, rustfmt; it installs the version a
      # project's rust-toolchain.toml names), the mold linker (-fuse-ld=mold in .cargo/config.toml)
      # and the cargo tools the projects use
      rustup mold bacon cargo-deny cargo-llvm-cov cargo-audit
      # Go
      go gopls delve golangci-lint gotools
      # C / C++
      gcc clang-tools cmake ninja meson pkg-config gnumake gdb lldb valgrind bear
      # Lua, Nix, shell, config files
      lua-language-server stylua nixd nixfmt shellcheck shfmt bash-language-server
      yaml-language-server taplo marksman
      # Containers
      docker-buildx docker-compose podman-compose dive lazydocker
      dockerfile-language-server docker-compose-language-service
      # Kubernetes
      kubectl kubernetes-helm k9s kind kubectx helm-ls
      # Infrastructure and cloud: Terraform/OpenTofu, Ansible, Hetzner, Oracle, Cloudflare
      terraform opentofu terraform-ls ansible ansible-language-server hcloud oci-cli
      cloudflared wrangler
      # AI coding agents
      claude-code codex opencode
      # Other CLIs you use
      gh aichat age openssl rclone just go-task taskwarrior3 yt-dlp tor
    ];
  };
}
