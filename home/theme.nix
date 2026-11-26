# GTK/Qt, cursor and the Zed theme. The
# terminals, btop and the other apps take their colours from the rendered theme (desktop.nix).
{ config, lib, pkgs, inputs, ... }:
let
  # The Zed theme "Omazed", rendered at build time by the generator from the omazed source
  # (flake input omazed), with the nord palette that the rest of the desktop uses.
  omazedTheme = pkgs.runCommand "omazed-theme" { nativeBuildInputs = [ pkgs.bash pkgs.gawk ]; } ''
    bash ${inputs.omazed}/omazed-generator.sh \
      ${./theme/colors.toml} $out \
      ${inputs.omazed}/omazed-theme.tpl dark
  '';
in
{
  xdg.configFile."zed/themes/omazed.json".source = "${omazedTheme}/omazed.json";

  # Same GNOME settings as the theme step writes on the live host: dark Adwaita, the icon theme
  # named by the theme's icons.theme, and the glass import (blur behind see-through GTK windows).
  gtk = {
    enable = true;
    theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; };
    iconTheme = { name = "Yaru-blue"; package = pkgs.yaru-theme; };
    font = { name = "Inter"; size = 11; };
    gtk4.extraCss = ''@import url("file://${pkgs.desktop-shell}/share/desktop-shell/default/gtk/glass.css");'';
  };
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-enable-primary-paste = true; # middle-click paste, as on the live host
  };
  qt = { enable = true; platformTheme.name = "gtk3"; };

  home.pointerCursor = {
    enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };
}
