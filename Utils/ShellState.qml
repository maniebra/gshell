pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    property bool controlCenter: false
    property bool launcher: false
    property bool dashboard: false
    // liquid neck joining an opening panel to the bar: screen name, screen x, width
    property var drip: ({ screen: "", x: 0, w: 0 })

    // qs -c gshell ipc call shell toggleControlCenter
    IpcHandler {
        target: "shell"
        function toggleControlCenter(): void { controlCenter = !controlCenter }
        function toggleLauncher(): void { launcher = !launcher }
        function toggleDashboard(): void { dashboard = !dashboard }
    }
}
