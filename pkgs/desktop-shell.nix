# The desktop shell is the upstream MIT source (flake input desktop-shell).
# It keeps upstream names for commands, environment variables and QML imports.
# Installed to $out/share/desktop-shell: shell/ bin/ default/ config/ themes/nord and the
# extra bar plugins (plugins/<id>). The helper commands in bin/ are NOT on the user's PATH;
# only the wrappers in $out/bin see them.
{ lib, stdenvNoCC, makeWrapper, perl, quickshell, hyprland, hyprsunset, jq, tailscale, gum,
  pulseaudio, networkmanager, curl, bluez, wireplumber, libsecret, brightnessctl, libnotify,
  power-profiles-daemon, playerctl, ddcutil, upower, python3, wl-clipboard, xdg-utils, openssl,
  socat, imagemagick, inotify-tools, coreutils, gnugrep, gnused, gawk, findutils, util-linux, procps, systemd, bash,
  gtk3, uwsm, xdg-terminal-exec, fontconfig, khal, ttfx,
  src, plugins ? { } }:
let
  runtimeTools = [
    quickshell hyprland hyprsunset jq tailscale gum pulseaudio networkmanager curl bluez
    wireplumber libsecret brightnessctl libnotify power-profiles-daemon playerctl ddcutil
    upower python3 wl-clipboard xdg-utils openssl socat imagemagick inotify-tools coreutils gnugrep gnused gawk findutils
    util-linux procps systemd bash
    khal # calendar panel events (khal list)
    ttfx # screensaver (bin/omarchy-screensaver)
    gtk3 uwsm xdg-terminal-exec fontconfig # app launch (uwsm-app, gtk-launch, terminal apps), font lookup (fc-match)
  ];
  share = "$out/share/desktop-shell";
in
stdenvNoCC.mkDerivation {
  pname = "desktop-shell";
  version = lib.fileContents "${src}/version";
  inherit src;
  nativeBuildInputs = [ makeWrapper perl python3 ]; # python3: patchShebangs finds it for the helper scripts
  dontBuild = true;

  # Battery panel: the switch "Limit charge to 80%" (UPower EnableChargeThreshold, no root).
  patches = [
    ./desktop-shell-charge-limit.patch
    ./desktop-shell-weather-week.patch
    ./desktop-shell-weather-bar.patch # bar item: icon and temperature
    ./desktop-shell-calendar-events.patch
    ./desktop-shell-clock-format.patch
    ./desktop-shell-weather-status.patch # right-click notification: same coordinates as the panel
    ./desktop-shell-system-update.patch # update icon: result of system-update-check; an unlock starts a check
  ];

  # NixOS has no /usr/bin (except env), no /usr/share/zoneinfo and no /etc/timezone.
  postPatch = ''
    # Super+` (drop-down console): a plain terminal (kitty through xdg-terminal-exec), not the AI agent.
    substituteInPlace default/hypr/qconsole.lua \
      --replace-fail 'hl.exec_cmd("omarchy-agent --pick", { workspace = CONSOLE .. " silent" })' \
                     'hl.exec_cmd("xdg-terminal-exec", { workspace = CONSOLE .. " silent" })'
    substituteInPlace shell/Commons/InputMethodState.qml --replace-fail '"/usr/bin/python3"' '"python3"'
    substituteInPlace shell/plugins/panels/elsewhen/Panel.qml \
      --replace-fail /usr/share/zoneinfo /etc/zoneinfo
    # Helper scripts: call tools through PATH (keep the first line, the shebang, for patchShebangs).
    find bin -type f -exec perl -pi -e 's#/usr/bin/(?!env\b)##g unless $. == 1' '{}' +


    # Web apps: nixpkgs names the Chromium desktop entry chromium-browser.desktop.
    substituteInPlace bin/omarchy-launch-webapp --replace-fail 'google-chrome.desktop chromium.desktop' 'google-chrome.desktop chromium-browser.desktop'

    # Menu: a menu that a row hides (`when` fails) hides all rows below it, in the search too.
    # The user extension file (home/config/omarchy-menu.jsonc) uses this to hide the Arch Linux menus.
    substituteInPlace shell/plugins/menu/MenuModel.js --replace-fail \
      '  if (entry.when && whenResults && whenResults[entry.id] === false) return false' \
      '  if (entry.when && whenResults && whenResults[entry.id] === false) return false
  for (var up = item(items, entry.parent); up; up = item(items, up.parent)) {
    if (up.when && whenResults && whenResults[up.id] === false) return false
  }'
    # Menu button: the NixOS logo (Nerd Font glyph nf-linux-nixos) instead of the upstream logo.
    substituteInPlace shell/plugins/menu/BarWidget.qml \
      --replace-fail 'text: "\ue900"' 'text: "\uf313"' \
      --replace-fail 'fontFamily: "omarchy"' 'fontFamily: "JetBrainsMono Nerd Font"'
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p ${share}/plugins $out/bin
    cp -r shell bin default config ${share}/
    mkdir -p ${share}/themes
    cp -r themes/nord ${share}/themes/nord
    cp LICENSE version icon.png ${share}/
    # The login theme (SDDM finds it in /run/current-system/sw/share/sddm/themes).
    mkdir -p $out/share/sddm/themes
    cp -r default/sddm/omarchy $out/share/sddm/themes/omarchy
    # The icon font of the shell (menu button, workspace glyphs): fontconfig finds it through fonts.packages.
    install -Dm444 default/fonts/omarchy/omarchy.ttf $out/share/fonts/truetype/omarchy.ttf
    # The header of the menu terminals (omarchy-show-logo) reads this file.
    echo NixOS > ${share}/logo.txt
    chmod -R u+w ${share}
    patchShebangs ${share}/bin ${share}/shell
    ${lib.concatStrings (lib.mapAttrsToList (id: plugin: ''
      cp -r ${plugin} ${share}/plugins/${id}
      chmod -R u+w ${share}/plugins/${id}
    '') plugins)}
    # Plugin paths: tools through PATH, the zone table where NixOS keeps it.
    ${lib.optionalString (plugins ? "io.github.ajanraj.disposable-email") ''
      grep -rl '"/usr/bin/' ${share}/plugins/io.github.ajanraj.disposable-email --include=*.qml |
        xargs sed -i 's#"/usr/bin/#"#g'
    ''}
    ${lib.optionalString (plugins ? "sviat.nightlight") ''
      substituteInPlace ${share}/plugins/sviat.nightlight/lib/nightlight/location.py \
        --replace-fail /usr/share/zoneinfo /etc/zoneinfo
    ''}
    # Third-party plugins use the bare name Color for the colour singleton of qs.Commons. Here
    # it resolves to undefined ("Unable to assign [undefined] to QColor"), so call it through
    # the alias that the shell itself uses (import qs.Commons as Commons).
    grep -rlE '(^|[^[:alnum:]_.])Color\.' ${share}/plugins --include=*.qml | while read -r f; do
      perl -0pi -e 's/(?<![\w.])Color\./Commons.Color./g; s/^import qs\.Commons\n/import qs.Commons\nimport qs.Commons as Commons\n/m unless /^import qs\.Commons as Commons/m' "$f"
    done
    patchShebangs ${share}/plugins

    # The shell, and the two helpers the Hyprland bindings call, all with the helper PATH.
    makeWrapper ${lib.getExe quickshell} $out/bin/desktop-shell \
      --add-flags "-n -p ${share}/shell" \
      --set OMARCHY_PATH ${share} --set-default QS_DISABLE_FILE_WATCHER 1 --set-default QS_NO_RELOAD_POPUP 1 \
      --prefix PATH : ${lib.makeBinPath runtimeTools}:${share}/bin
    makeWrapper ${share}/bin/omarchy-shell $out/bin/desktop-shell-ipc \
      --set OMARCHY_PATH ${share} --prefix PATH : ${lib.makeBinPath runtimeTools}:${share}/bin
    makeWrapper ${share}/bin/omarchy-toggle-bar $out/bin/desktop-shell-toggle-bar \
      --set OMARCHY_PATH ${share} --prefix PATH : ${lib.makeBinPath runtimeTools}:${share}/bin
    runHook postInstall
  '';

  # The helper tools of bin/ and of the shell: modules/desktop.nix puts them on the session PATH.
  passthru = { inherit runtimeTools; };

  meta = {
    description = "Desktop shell: bar, panels, notifications (upstream QML shell, pinned)";
    homepage = "https://github.com/omacom/omarchy";
    license = lib.licenses.mit;
    mainProgram = "desktop-shell";
    platforms = lib.platforms.linux;
  };
}
