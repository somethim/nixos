# Boot splash theme of the desktop shell (default/plymouth). The upstream theme has the name omarchy.
# The logo is the NixOS snowflake (256x256, centered by the theme script), not the upstream logo.
# The theme file points to /usr/share, so the build points it to the store path.
{ stdenvNoCC, nixos-icons, src }:
stdenvNoCC.mkDerivation {
  pname = "plymouth-theme-omarchy";
  version = "4.5.0";
  inherit src;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    theme=$out/share/plymouth/themes/omarchy
    mkdir -p $theme
    cp -r --no-preserve=mode . $theme
    cp ${nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png $theme/logo.png
    rm -r $theme/logos
    substituteInPlace $theme/omarchy.plymouth --replace-fail /usr/share/plymouth/themes/omarchy $theme
    runHook postInstall
  '';
}
