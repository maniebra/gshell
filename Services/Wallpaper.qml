pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Current hyprpaper wallpaper per monitor: { "eDP-1": "/path.jpg", ... }
Singleton {
    property var paths: ({})

    function pathFor(name) { return paths[name] ?? "" }

    Process {
        id: proc
        command: ["hyprctl", "hyprpaper", "listactive"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf(": ");
                    if (i > 0) m[line.slice(0, i)] = line.slice(i + 2).trim();
                }
                paths = m;
            }
        }
    }

    // ponytail: polling, switch to hyprpaper IPC events if 10s lag on rotation matters
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
}
