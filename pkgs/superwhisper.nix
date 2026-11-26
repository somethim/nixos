{ lib, stdenv, fetchurl, zstd, autoPatchelfHook, makeWrapper, makeDesktopItem
, copyDesktopItems, wrapGAppsHook4, autoAddDriverRunpath, gtk4, gtk4-layer-shell
, libxkbcommon, libxcb, vulkan-loader, fontconfig, librsvg, ffmpeg, foot, libnotify
, wl-clipboard, xdg-utils, pulseaudio, python3, at-spi2-core, fcitx5 }:

let
  version = "1.3.1";
  python = python3.withPackages (ps: with ps; [ pygobject3 pycairo ]);
in
stdenv.mkDerivation {
  pname = "superwhisper";
  inherit version;
  src = fetchurl {
    url = "https://tux.superwhisper.com/x86_64/v${version}/superwhisper-omarchy-x86_64-${version}.tar.zst";
    hash = "sha256-RkpzLKbJKNPyuLuUaHF2p1yisJwYYzPTTZTQUcy18OQ=";
  };

  nativeBuildInputs = [
    zstd autoPatchelfHook makeWrapper copyDesktopItems wrapGAppsHook4 autoAddDriverRunpath
  ];
  buildInputs = [
    stdenv.cc.cc.lib gtk4 gtk4-layer-shell libxkbcommon libxcb vulkan-loader
    fontconfig librsvg at-spi2-core fcitx5
  ];

  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  desktopItems = [
    (makeDesktopItem {
      name = "superwhisper";
      desktopName = "Superwhisper";
      exec = "superwhisper settings";
      icon = "superwhisper";
      categories = [ "Utility" ];
    })
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/bin" "$out/share/licenses/superwhisper"
    cp -r app "$out/lib/superwhisper"
    cp -r licenses/. "$out/share/licenses/superwhisper/"
    for size in 16 32 64 128 256 512; do
      install -Dm644 "app/assets/app-icon/$size.png" \
        "$out/share/icons/hicolor/$size"x"$size/apps/superwhisper.png"
    done
    # The fcitx5 text-insertion addon. fcitx5 finds its description file in share/fcitx5/addon
    # of a package in i18n.inputMethod.fcitx5.addons (modules/desktop.nix). The description
    # file needs the path of the library.
    mkdir -p "$out/share/fcitx5/addon"
    substitute app/assets/fcitx5/superwhisper.conf.in "$out/share/fcitx5/addon/superwhisper.conf" \
      --subst-var-by LIBRARY "$out/lib/superwhisper/lib/fcitx5/libsuperwhisper-fcitx5"
    patchShebangs "$out/lib/superwhisper"
    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/lib/superwhisper/lib"
    makeWrapper "$out/lib/superwhisper/run.sh" "$out/bin/superwhisper" \
      --prefix PATH : ${lib.makeBinPath [ python xdg-utils ffmpeg foot libnotify wl-clipboard pulseaudio ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ gtk4-layer-shell vulkan-loader ]} \
      "''${gappsWrapperArgs[@]}"
    addDriverRunpath "$out/lib/superwhisper/bin/cleanup-worker-vulkan"
  '';

  meta = {
    description = "Voice dictation for Linux";
    homepage = "https://superwhisper.com/linux";
    license = lib.licenses.unfree;
    mainProgram = "superwhisper";
    platforms = [ "x86_64-linux" ];
  };
}
