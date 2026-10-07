pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    property bool controlCenter: false
    property bool launcher: false
    property bool dashboard: false
    // dynamic island: opened by press-and-hold on the bar clock, stays open
    // while the clock or the island itself is hovered
    property bool island: false
    property bool islandHoverBar: false
    property real islandFrom: 150 // width of the bar's capsule, where the island grows from
    property bool islandHoverCard: false
    // app icon look: "default" | "dark" | "clear" | "tinted"
    property alias iconStyle: settings.iconStyle
    property alias iconTint: settings.iconTint
    property alias accent: settings.accent
    property alias accentFromArt: settings.accentFromArt
    property alias iconTintFromArt: settings.iconTintFromArt

    FileView {
        path: Quickshell.statePath("settings.json")
        blockLoading: true // apply saved settings before first frame
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: e => { if (e === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: settings
            property string iconStyle: "default"
            property string iconTint: "#ffd60a"
            property string accent: "#0a84ff"
            property bool accentFromArt: false
            property bool iconTintFromArt: false
        }
    }

    // qs -c gshell ipc call shell toggleControlCenter
    IpcHandler {
        target: "shell"
        function toggleControlCenter(): void { controlCenter = !controlCenter }
        function toggleLauncher(): void { launcher = !launcher }
        function toggleDashboard(): void { dashboard = !dashboard }
        function toggleIsland(): void { island = !island }
    }
}
