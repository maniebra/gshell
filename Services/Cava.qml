pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Live audio spectrum from cava: `bars` holds 5 levels in 0..1.
// Runs only while `active` (bind it to "something is playing").
Singleton {
    id: root
    property bool active: false
    property var bars: [0, 0, 0, 0, 0]

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.shellPath("Services/cava.conf")]
        stdout: SplitParser {
            onRead: line => root.bars = line.split(";").filter(x => x !== "").map(x => Number(x) / 100)
        }
        onRunningChanged: if (!running) root.bars = [0, 0, 0, 0, 0]
    }
}
