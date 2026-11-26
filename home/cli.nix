# Bash and command-line tools: aliases, zoxide `cd`, fzf, starship prompt.
{ pkgs, ... }:
{
  programs.bash = {
    enable = true;
    historySize = 32768;
    historyFileSize = 32768;
    historyControl = [ "ignoreboth" ];
    shellOptions = [ "histappend" ];
    sessionVariables = {
      SUDO_EDITOR = "nvim";
      BAT_THEME = "ansi";
      MANROFFOPT = "-c";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };
    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lsa = "ls -a";
      lt = "eza --tree --level=2 --long --icons --git";
      lta = "lt -a";
      ff = "fzf --preview 'bat --style=numbers --color=always {}'";
      eff = "$EDITOR \"$(ff)\"";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      c = "opencode --auto";
      cx = "printf '\\033[2J\\033[3J\\033[H' && claude --permission-mode auto";
      cy = "codex --approve-for-me";
      cf = "bunx cf";
      d = "docker";
      t = "tmux attach || tmux new -s Work";
      h = "herdr";
      g = "git";
      gcm = "git commit -m";
      gcam = "git commit -a -m";
      gcad = "git commit -a --amend";
      sail = "sh $([ -f sail ] && echo sail || echo vendor/bin/sail)";
      ai = "OPENCODE_CONFIG=$HOME/.config/opencode/npu.json opencode --standalone";
    };
    initExtra = ''
      # n: open nvim in the current folder, or the given files.
      n() { if [ "$#" -eq 0 ]; then command nvim . ; else command nvim "$@"; fi; }
      # open: open files with their default app, without blocking the terminal.
      open() ( xdg-open "$@" >/dev/null 2>&1 & )
      export PATH="$HOME/.local/bin:$HOME/.config/composer/vendor/bin:$PATH"
    '';
  };

  programs.zoxide = { enable = true; options = [ "--cmd cd" ]; }; # `cd zero` jumps to zero2prod
  programs.fzf.enable = true;
  programs.starship.enable = true;    # prompt; settings in home/config/starship.toml
  programs.eza.enable = true;
  programs.bat.enable = true;

  # LazyVim config is linked from home/config/nvim (home/default.nix), so HM
  # writes no init.lua. Language servers and formatters come from modules/dev.nix;
  # extraPackages are the tools only Neovim needs (treesitter parser build, lazy.nvim
  # and snacks downloads). ripgrep, fd and lazygit are in home.packages below;
  # wl-clipboard comes from waylandSupport.
  programs.neovim = {
    enable = true;
    defaultEditor = true; # EDITOR and VISUAL
    viAlias = true;
    vimAlias = true;
    # init.lua is the LazyVim one from the linked ~/.config/nvim; the generated part loads through the wrapper.
    sideloadInitLua = true;
    extraPackages = with pkgs; [ tree-sitter git curl unzip gnumake gcc ];
  };

  home.packages = with pkgs; [ tmux fd ripgrep jq tldr fastfetch btop lazygit herdr cliamp ];
}
