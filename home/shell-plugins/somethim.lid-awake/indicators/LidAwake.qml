import QtQuick
import qs.Ui

// Keeps a laptop running with the lid closed (see bin/lid-awake). Hidden on
// machines without a lid.
BarIndicator {
  id: root

  readonly property var hostState: indicatorHost && indicatorHost.hostState ? indicatorHost.hostState : ({})
  readonly property bool available: hostState.lid === "on" || hostState.lid === "off"

  visible: available && belongsInBlock && (text !== "" || keepSpace)
  active: hostState.lid === "on"
  activeText: "󰒳"
  inactiveText: "󰒳"
  activeTooltipText: "Sleep When the Lid Closes"
  inactiveTooltipText: "Lid Awake"

  onPressed: function() { if (root.indicatorHost) root.indicatorHost.runStateAction("lid") }
}
