import QtQuick
import qs.Ui

BarIndicator {
  id: root

  readonly property var hostState: indicatorHost && indicatorHost.hostState ? indicatorHost.hostState : ({})

  active: hostState.stayAwake === true
  activeText: "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: "Allow Idle Lock & Screensaver"
  inactiveTooltipText: "Stay Awake"

  onPressed: function() { if (root.indicatorHost) root.indicatorHost.runStateAction("idle") }
}
