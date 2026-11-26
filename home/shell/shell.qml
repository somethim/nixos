//@ pragma UseQApplication
import QtQuick
import Quickshell

// The picker (apps, clipboard, emoji, keybindings, system menu).
// The bar and notifications belong to the desktop-shell package (pkgs/desktop-shell.nix).
// Hyprland keybindings call these through `quickshell ipc -c desktop call ...`.
ShellRoot {
  Picker {}
}
