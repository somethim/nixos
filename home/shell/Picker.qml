import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// One searchable picker with modes: apps, clipboard, emoji, keys, system.
// Open with: quickshell ipc call picker toggle <mode>
PanelWindow {
  id: root
  visible: false
  anchors { top: true; bottom: true; left: true; right: true }
  color: Qt.rgba(0, 0, 0, 0.25)
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "shell-picker"
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  property string mode: "apps"
  property var items: []
  property var source: []

  readonly property var titles: ({ apps: "Apps", clipboard: "Clipboard", emoji: "Emoji", keys: "Keybindings", system: "System" })

  function open(m) {
    mode = m; search.text = ""; source = [];
    if (m === "apps") source = appItems();
    else if (m === "system") source = systemItems();
    else if (m === "clipboard") clip.running = true;
    else if (m === "emoji") source = emojiItems();
    else if (m === "keys") binds.running = true;
    filter(); visible = true; search.forceActiveFocus();
  }
  function close() { visible = false }
  function run(argv) { Quickshell.execDetached(argv) }

  function appItems() {
    return DesktopEntries.applications.values
      .filter(e => !e.noDisplay)
      .map(e => ({ label: e.name, detail: e.genericName || e.comment || "", icon: e.icon,
                   keys: [e.name, e.genericName, e.comment].concat(e.keywords).join(" ").toLowerCase(),
                   act: () => e.execute() }))
      .sort((a, b) => a.label.localeCompare(b.label));
  }
  function systemItems() {
    const sh = cmd => () => run(["sh", "-c", cmd]);
    const term = cmd => () => run(["xdg-terminal-exec"].concat(cmd));
    return [
      { label: "Lock", detail: "Super+Ctrl+L", glyph: "", act: () => run(["desktop-shell-ipc", "lock", "lock"]) },
      { label: "Suspend", glyph: "", act: sh("systemctl suspend") },
      { label: "Log out", glyph: "", act: sh("uwsm stop") },
      { label: "Restart", glyph: "", act: sh("systemctl reboot") },
      { label: "Shut down", glyph: "", act: sh("systemctl poweroff") },
      { label: "Wi-Fi", detail: "nmtui", glyph: "󰖩", act: term(["nmtui"]) },
      { label: "Bluetooth", detail: "bluetui", glyph: "", act: term(["bluetui"]) },
      { label: "Sound", detail: "wiremix", glyph: "󰕾", act: term(["wiremix"]) },
      { label: "Power profile", detail: "cycle saver / balanced / performance", glyph: "",
        act: sh("p=$(powerprofilesctl get); case $p in power-saver) n=balanced;; balanced) n=performance;; *) n=power-saver;; esac; powerprofilesctl set $n && notify-send -t 2000 'Power profile' $n") },
      { label: "Do not disturb", detail: "on / off", glyph: "", act: () => run(["desktop-shell-ipc", "notifications", "toggleDnd"]) },
      { label: "Clipboard history", detail: "Super+Ctrl+V", glyph: "󰅌", act: () => Qt.callLater(() => open("clipboard")), keep: true },
      { label: "Emoji", detail: "Super+Ctrl+E", glyph: "", act: () => Qt.callLater(() => open("emoji")), keep: true },
      { label: "Keybindings", detail: "Super+K", glyph: "", act: () => Qt.callLater(() => open("keys")), keep: true },
      { label: "Screenshot", detail: "Print", glyph: "", act: sh("sleep 0.3; omasnap") },
      { label: "Webcam recorder", glyph: "", act: sh("monologue") },
    ].map(i => Object.assign({ keys: (i.label + " " + (i.detail || "")).toLowerCase() }, i));
  }
  function emojiItems() {
    try {
      return JSON.parse(emojiFile.text()).map(e => ({ label: e[0] + "  " + e[1], keys: e[1].toLowerCase(),
        act: () => run(["sh", "-c", "printf %s '" + e[0] + "' | wl-copy && notify-send -t 1500 'Copied' '" + e[0] + "'"]) }));
    } catch (err) { return [] }
  }
  function filter() {
    const q = search.text.toLowerCase().trim();
    const words = q.split(/\s+/).filter(w => w);
    items = source.filter(i => words.every(w => i.keys.includes(w))).slice(0, 200);
    list.currentIndex = 0;
  }
  function activate(i) {
    const item = items[i];
    if (!item) return;
    if (!item.keep) close();
    if (item.act) item.act();
  }

  // App entries load in the background; refresh an open app list when they arrive.
  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { if (root.visible && root.mode === "apps") { root.source = root.appItems(); root.filter() } }
  }

  FileView { id: emojiFile; path: Qt.resolvedUrl("emoji.json"); blockLoading: true }
  Process {
    id: clip
    command: ["cliphist", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.mode !== "clipboard") return;
        root.source = text.split("\n").filter(l => l).map(l => {
          const tab = l.indexOf("\t"), id = l.slice(0, tab), preview = l.slice(tab + 1);
          return { label: preview, keys: preview.toLowerCase(),
                   act: () => root.run(["sh", "-c", "cliphist decode " + id + " | wl-copy"]) };
        });
        root.filter();
      }
    }
  }
  Process {
    id: binds
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.mode !== "keys") return;
        const names = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]];
        try {
          root.source = JSON.parse(text).filter(b => b.has_description).map(b => {
            const combo = names.filter(([bit]) => b.modmask & bit).map(([, n]) => n).concat([b.key]).join(" + ");
            return { label: b.description, detail: combo, keys: (b.description + " " + combo).toLowerCase() };
          });
        } catch (e) { root.source = [] }
        root.filter();
      }
    }
  }

  MouseArea { anchors.fill: parent; onClicked: root.close() }

  Rectangle {
    id: box
    anchors.centerIn: parent
    width: 680; height: 470
    radius: Theme.radius
    color: Theme.panelSolid
    border.color: Theme.accent
    border.width: 1
    MouseArea { anchors.fill: parent }   // clicks inside don't close

    Column {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      TextField {
        id: search
        width: parent.width
        placeholderText: root.titles[root.mode] + "…"
        color: Theme.fg
        placeholderTextColor: Theme.fgDim
        font.family: Theme.fontUi
        font.pixelSize: 16
        background: Rectangle { radius: 8; color: Theme.bgLight }
        onTextChanged: root.filter()
        Keys.onEscapePressed: root.close()
        Keys.onDownPressed: list.incrementCurrentIndex()
        Keys.onUpPressed: list.decrementCurrentIndex()
        Keys.onReturnPressed: root.activate(list.currentIndex)
        Keys.onEnterPressed: root.activate(list.currentIndex)
      }

      ListView {
        id: list
        width: parent.width
        height: parent.height - search.height - 10
        clip: true
        model: root.items
        highlightMoveDuration: 80
        highlight: Rectangle { radius: 8; color: Theme.sel }
        delegate: Item {
          required property var modelData
          required property int index
          width: list.width
          height: 40
          Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            spacing: 12
            Item {
              width: 22; height: 22
              Image {
                anchors.fill: parent
                visible: !!modelData.icon
                source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                sourceSize: Qt.size(22, 22)
              }
              BarText { anchors.centerIn: parent; visible: !!modelData.glyph; text: modelData.glyph || ""; color: Theme.accent; font.pixelSize: 16 }
            }
            BarText {
              text: modelData.label
              font.family: Theme.fontUi
              font.pixelSize: 14
              elide: Text.ElideRight
              width: list.width - 260
            }
          }
          BarText {
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.detail || ""
            color: Theme.fgDim
            elide: Text.ElideRight
            width: 200
            horizontalAlignment: Text.AlignRight
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: list.currentIndex = index
            onClicked: root.activate(index)
          }
        }
      }
    }
  }

  IpcHandler {
    target: "picker"
    function toggle(mode: string): void { if (root.visible && root.mode === mode) root.close(); else root.open(mode) }
    function open(mode: string): void { root.open(mode) }
    function close(): void { root.close() }
  }
}
