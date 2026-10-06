pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// CPU / memory / disk / temperature, polled while `active` (set by the dashboard).
Singleton {
    id: root
    property bool active: false
    property real cpu: 0    // 0..1
    property real mem: 0    // 0..1
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real disk: 0   // 0..1, root fs
    property real temp: 0   // °C, CPU package
    property var cpuHistory: []

    property var last: null

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process {
        id: probe
        command: ["sh", "-c", `
            head -1 /proc/stat
            awk '/^MemTotal|^MemAvailable/{print $1, $2}' /proc/meminfo
            for z in /sys/class/thermal/thermal_zone*; do
                [ "$(cat $z/type)" = x86_pkg_temp ] && echo "temp $(cat $z/temp)" && break
            done
            df -P / | awk 'NR==2{print "disk", $5}'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                let total = 0, avail = 0;
                for (const line of text.trim().split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f[0] === "cpu") {
                        const v = f.slice(1).map(Number);
                        const idle = v[3] + v[4], sum = v.reduce((a, b) => a + b, 0);
                        if (root.last) {
                            const dt = sum - root.last.sum;
                            root.cpu = dt > 0 ? 1 - (idle - root.last.idle) / dt : 0;
                            root.cpuHistory = root.cpuHistory.concat([root.cpu]).slice(-30);
                        }
                        root.last = { idle, sum };
                    } else if (f[0] === "MemTotal:") total = +f[1];
                    else if (f[0] === "MemAvailable:") avail = +f[1];
                    else if (f[0] === "temp") root.temp = +f[1] / 1000;
                    else if (f[0] === "disk") root.disk = parseInt(f[1]) / 100;
                }
                if (total > 0) {
                    root.mem = 1 - avail / total;
                    root.memUsedGb = (total - avail) / 1048576;
                    root.memTotalGb = total / 1048576;
                }
            }
        }
    }
}
