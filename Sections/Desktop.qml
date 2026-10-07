import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Components
import qs.Utils

// Transparent layer over the wallpaper on each screen; right click opens the
// desktop menu. Windows sit above it, so it only sees clicks on bare desktop.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "gshell-desktop"

        function run(cmd) { Quickshell.execDetached(cmd) }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: m => menu.openItems([
                { text: "Open Terminal", act: () => win.run(["kitty"]) },
                { text: "Open Files", act: () => win.run(["xdg-open", Quickshell.env("HOME")]) },
                { separator: true },
                { text: "Launcher", act: () => ShellState.launcher = true },
                { text: "Dashboard", act: () => ShellState.dashboard = true },
                { text: "Control Center", act: () => ShellState.controlCenter = true },
                { separator: true },
                { text: "Reload Shell", act: () => Quickshell.reload(true) }
            ], m.x, m.y)
        }

        TrayMenu { id: menu; scr: win.modelData }
    }
}
