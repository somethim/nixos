# Two small desktop apps built from their upstream repos (MIT):
# omasnap (screenshots with annotation and scrolling capture) and monologue
# (webcam recorder).
{ lib, stdenv, cmake, pkg-config, qt6, kdePackages, wayland, wayland-scanner,
  wayland-protocols, libdeflate, libpulseaudio, libjpeg_turbo, sources }:
{
  omasnap = stdenv.mkDerivation {
    pname = "omasnap";
    version = "0-unstable";
    src = sources.omasnap;
    nativeBuildInputs = [ cmake pkg-config qt6.wrapQtAppsHook wayland-scanner ];
    buildInputs = [ qt6.qtbase qt6.qtwayland kdePackages.layer-shell-qt wayland wayland-protocols libdeflate ];
    # Upstream reads the protocol XML files from /usr/share/wayland-protocols.
    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace-fail /usr/share/wayland-protocols ${wayland-protocols}/share/wayland-protocols
    '';
    meta = {
      description = "Wayland screenshot and annotation overlay with scrolling capture";
      homepage = "https://github.com/omacom/omasnap";
      license = lib.licenses.mit;
      mainProgram = "omasnap";
      platforms = lib.platforms.linux;
    };
  };

  monologue = stdenv.mkDerivation {
    pname = "monologue";
    version = "0-unstable";
    src = sources.monologue;
    nativeBuildInputs = [ cmake pkg-config qt6.wrapQtAppsHook ];
    buildInputs = [
      qt6.qtbase qt6.qtdeclarative qt6.qtwayland qt6.qtsvg qt6.qtmultimedia libpulseaudio libjpeg_turbo
    ];
    # Upstream installs the binary, launcher and icon through its distro package, not CMake.
    installPhase = ''
      runHook preInstall
      install -Dm755 monologue $out/bin/monologue
      install -Dm644 $src/pkgbuild/monologue.desktop $out/share/applications/monologue.desktop
      install -Dm644 $src/pkgbuild/monologue.svg $out/share/icons/hicolor/scalable/apps/monologue.svg
      runHook postInstall
    '';
    meta = {
      description = "Webcam recorder";
      homepage = "https://github.com/omacom/monologue";
      license = lib.licenses.mit;
      mainProgram = "monologue";
      platforms = lib.platforms.linux;
    };
  };
}
