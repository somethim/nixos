import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "somethim.vitals"

  // Readings in percent (temperature in degrees C). -1 means no reading yet.
  property int cpu: -1
  property int gpu: -1
  property int npu: -1
  property int memory: -1
  property int temperature: -1

  // Counters from the previous sample, to turn totals into percent.
  property real lastTotal: 0
  property real lastIdle: 0

  readonly property int memoryWarningAt: Number(root.settings.memoryWarning || 95)
  readonly property int temperatureWarningAt: Number(root.settings.temperatureWarning || 90)
  readonly property bool warning: root.memory >= root.memoryWarningAt
    || root.temperature >= root.temperatureWarningAt

  function pct(value) { return value < 0 ? "--" : value + "%" }

  function parse(text) {
    var lines = String(text || "").split("\n")
    var memTotal = 0
    var memAvailable = -1
    root.cpu = root.gpu = root.npu = root.memory = root.temperature = -1
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      if (f[0] === "cpu" && f.length >= 9) {
        // Guest time is included in user and nice time.
        var total = 0
        for (var j = 1; j <= 8; j++) total += Number(f[j])
        var idle = Number(f[4]) + Number(f[5])
        if (root.lastTotal > 0 && total > root.lastTotal && idle >= root.lastIdle)
          root.cpu = Math.max(0, Math.round(100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal))))
        root.lastTotal = total
        root.lastIdle = idle
      } else if (f[0] === "MemTotal:") memTotal = Number(f[1])
      else if (f[0] === "MemAvailable:") memAvailable = Number(f[1])
      else if (f[0] === "gpu" && /^[0-9]+$/.test(f[1]) && Number(f[1]) <= 100) root.gpu = Number(f[1])
      else if (f[0] === "temp" && /^[0-9]+$/.test(f[1])) root.temperature = Math.round(Number(f[1]) / 1000)
      // A suspended NPU is idle. The PCI power state gives no load reading in D0.
      else if (f[0] === "npustate" && (f[1] === "D3hot" || f[1] === "D3cold")) root.npu = 0
    }
    if (memTotal > 0 && memAvailable >= 0 && memAvailable <= memTotal)
      root.memory = Math.round((memTotal - memAvailable) * 100 / memTotal)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: sampler
    command: ["sh", "-c", [
      "head -n1 /proc/stat",
      "grep -E '^Mem(Total|Available):' /proc/meminfo",
      "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && echo \"gpu $(cat \"$f\")\" && break; done",
      "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$h/name\" 2>/dev/null)\" = k10temp ] && echo \"temp $(cat \"$h/temp1_input\")\" && break; done",
      "for d in /sys/class/accel/accel*/device; do case \"$(readlink \"$d/driver\")\" in */amdxdna) echo \"npustate $(cat \"$d/power_state\" 2>/dev/null)\"; break;; esac; done"
    ].join("; ")]
    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!sampler.running) sampler.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "CPU " + root.pct(root.cpu) + " GPU " + root.pct(root.gpu) + " NPU " + root.pct(root.npu)
      + " RAM " + root.pct(root.memory) + " " + (root.temperature < 0 ? "--" : root.temperature + "°C")
    active: root.warning
    horizontalMargin: 2
    tooltipText: ""
    onPressed: function(buttonCode) {
      if (root.bar) root.bar.run("xdg-terminal-exec btop")
    }
  }
}
