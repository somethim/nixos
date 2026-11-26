import QtQuick
import qs.Ui

BarIndicator {
  id: root

  readonly property var hostState: indicatorHost && indicatorHost.hostState ? indicatorHost.hostState : ({})

  active: hostState.dnd === true
  activeText: "󰂛"
  inactiveText: "󰂛"
  activeTooltipText: "Allow Notifications"
  inactiveTooltipText: "Silence Notifications"

  onPressed: function() { if (root.indicatorHost) root.indicatorHost.runStateAction("dnd") }
}
