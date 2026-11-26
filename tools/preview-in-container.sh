# Runs inside the nixos/nix container (see shell-preview.sh).
set -eu
export NIX_CONFIG="experimental-features = nix-command flakes"
pkgs="nixpkgs#dbus nixpkgs#sway-unwrapped nixpkgs#quickshell nixpkgs#grim nixpkgs#jq nixpkgs#curl nixpkgs#procps nixpkgs#bash nixpkgs#gawk nixpkgs#coreutils nixpkgs#python3"
FONTCONFIG_FILE=$(nix build --no-link --print-out-paths --impure --expr 'with import (builtins.getFlake "nixpkgs") {}; makeFontsConf { fontDirectories = [ nerd-fonts.jetbrains-mono inter noto-fonts noto-fonts-color-emoji ]; }')
export FONTCONFIG_FILE
mkdir -p /tmp/xdg /tmp/shell && chmod 700 /tmp/xdg
export XDG_RUNTIME_DIR=/tmp/xdg
cp -r /src/home/shell/. /tmp/shell/ && nix eval --json --impure --expr 'import /src/home/theme/palette.nix (builtins.fromTOML (builtins.readFile /src/home/theme/colors.toml))' > /tmp/shell/palette.json
mkdir -p /tmp/bin
printf '[["😀","grinning face"],["👍","thumbs up"]]' > /tmp/shell/emoji.json
printf 'output HEADLESS-1 resolution 1920x1200\n' > /tmp/sway.conf
cat > /tmp/session.sh <<'SESSION'
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 sway -c /tmp/sway.conf >/out/sway.log 2>&1 &
sleep 3
export WAYLAND_DISPLAY=wayland-1 QT_QUICK_BACKEND=software QT_QPA_PLATFORM=wayland PATH=/tmp/bin:$PATH
ipc() { quickshell ipc -p /tmp/shell call "$@"; }
quickshell -p /tmp/shell >/out/shell.log 2>&1 &
sleep 8
ipc picker open apps; sleep 2; grim /out/picker-apps.png
ipc picker open system; sleep 2; grim /out/picker-system.png
ipc picker close
SESSION
nix shell $pkgs -c sh -c 'dbus-run-session --config-file="$(dirname "$(readlink -f "$(command -v dbus-daemon)")")/../share/dbus-1/session.conf" sh /tmp/session.sh'
chown -R 1000:1000 /out
