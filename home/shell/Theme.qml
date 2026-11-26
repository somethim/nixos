pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colours and sizes for the whole shell. Colours come from palette.json,
// which the build makes from home/theme/colors.toml.
Singleton {
  id: root

  property var p: ({})
  function c(key, fallback) { return p[key] !== undefined ? p[key] : fallback }

  readonly property color bg: c("bg", "#2e3440")
  readonly property color bgDark: c("bgDark", "#242933")
  readonly property color bgLight: c("bgLight", "#3b4252")
  readonly property color sel: c("sel", "#434c5e")
  readonly property color fg: c("fg", "#d8dee9")
  readonly property color fgDim: c("fgDim", "#7b88a1")
  readonly property color muted: c("muted", "#4c566a")
  readonly property color accent: c("accent", "#88c0d0")
  readonly property color accent2: c("accent2", "#81a1c1")
  readonly property color red: c("red", "#bf616a")
  readonly property color orange: c("orange", "#d08770")
  readonly property color yellow: c("yellow", "#ebcb8b")
  readonly property color green: c("green", "#a3be8c")

  // Glass: panels are slightly see-through; Hyprland blurs what is behind them.
  readonly property color panel: Qt.rgba(bgDark.r, bgDark.g, bgDark.b, 0.82)
  readonly property color panelSolid: Qt.rgba(bgDark.r, bgDark.g, bgDark.b, 0.94)

  readonly property string font: c("font", "JetBrainsMono Nerd Font")
  readonly property string fontUi: c("fontUi", "Inter")
  readonly property int barHeight: 30
  readonly property int fontSize: 12
  readonly property int radius: 10
  readonly property int gap: 10

  FileView {
    path: Qt.resolvedUrl("palette.json")
    onLoaded: root.p = JSON.parse(text())
  }
}
