pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Per-monitor brightness: laptop panels via brightnessctl, externals via
// DDC/CI (ddcutil). Monitors that support neither are left out.
Singleton {
    id: root
    // [{ name: "eDP-1", kind: "backlight" | "ddc", bus, value: 0..1 }]
    property var displays: []

    function refresh() { probe.running = true }

    function set(d, v) {
        d.value = v;
        if (d.kind === "backlight")
            Quickshell.execDetached(["brightnessctl", "-q", "s", Math.round(v * 100) + "%"]);
        else { d.pending = v; ddcTimer.restart() }
    }

    // ddcutil writes take ~100ms, coalesce slider drags
    Timer {
        id: ddcTimer
        interval: 150
        onTriggered: {
            for (const d of root.displays)
                if (d.pending !== undefined) {
                    Quickshell.execDetached(["ddcutil", "-b", d.bus, "--noverify", "setvcp", "10", Math.round(d.pending * 100)]);
                    delete d.pending;
                }
        }
    }

    Process {
        id: probe
        // backlight line: "B <percent>"; per working DDC display: "D <connector> <bus> <cur> <max>"
        command: ["sh", "-c", `
            brightnessctl -m -c backlight 2>/dev/null | awk -F, '{ sub("%","",$4); print "B", $4 }'
            ddcutil detect --terse 2>/dev/null | awk '/^Display/{ok=1} /^Invalid/{ok=0}
                ok && /I2C bus/{ sub(".*i2c-","",$0); bus=$0 } ok && /DRM connector/{ sub(".*card[0-9]+-","",$0); print bus, $0 }' |
            while read bus conn; do
                set -- $(ddcutil -b "$bus" getvcp 10 --brief 2>/dev/null)
                [ "$4" ] && echo D "$conn" "$bus" "$4" "$5"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.trim().split("\n")) {
                    const f = l.split(" ");
                    if (f[0] === "B") out.push({ name: "Built-in Display", kind: "backlight", value: +f[1] / 100 });
                    else if (f[0] === "D") out.push({ name: f[1], kind: "ddc", bus: f[2], value: +f[3] / (+f[4] || 100) });
                }
                root.displays = out;
            }
        }
    }

    Component.onCompleted: refresh()
}
