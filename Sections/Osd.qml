import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Services
import qs.Components
import qs.Utils

// iOS-style popups for volume and keyboard layout changes: a glass card that
// slides up from the bottom edge of the focused screen, then back down.
PanelWindow {
    id: win
    property string kind: "" // "volume" | "layout"
    property string layout: ""
    property bool shown: false
    // ignore the initial values reported at startup
    property bool ready: false

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    visible: shown || glass.opacity > 0
    color: "transparent"
    WlrLayershell.namespace: "gshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true // horizontally centered by the compositor
    readonly property int lift: 48 // gap between card and screen bottom
    implicitWidth: 240
    implicitHeight: 52 + lift
    mask: Region {} // never takes input

    function pop(k) {
        if (!ready) return;
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer { interval: 1000; running: true; onTriggered: win.ready = true }
    Timer { id: hide; interval: 1400; onTriggered: win.shown = false }

    Connections {
        target: Audio
        function onVolumeChanged() { win.pop("volume") }
        function onMutedChanged() { win.pop("volume") }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name !== "activelayout") return;
            win.layout = e.data.split(",").slice(1).join(",");
            win.pop("layout");
        }
    }

    Backdrop {
        id: backdrop
        screen: win.screen
        active: win.shown
    }

    GlassSurface {
        id: glass
        backdrop: backdrop.texture
        offset: Qt.point(((win.screen?.width ?? 0) - win.width) / 2, (win.screen?.height ?? 0) - win.height)
        width: parent.width; height: 52
        // hidden: just below the window's bottom edge
        y: win.shown ? 0 : win.height
        moving: y
        radius: Theme.radiusTile
        bevel: 14
        tint: Qt.rgba(0.02, 0.02, 0.04, 0.45)
        vibrancy: 0.6
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        // volume: icon + level bar
        Row {
            anchors.centerIn: parent
            spacing: 12
            visible: win.kind === "volume"
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: Audio.muted || Audio.volume < 0.01 ? Icons.volOff : Icons.vol
                font.pixelSize: 16
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 150; height: 6; radius: 3
                color: Theme.fill
                Rectangle {
                    width: parent.width * (Audio.muted ? 0 : Math.min(1, Audio.volume))
                    height: parent.height; radius: parent.radius
                    color: Theme.fg
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                text: Audio.muted ? "" : Math.round(Audio.volume * 100)
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.fgDim
            }
        }

        // keyboard layout
        StyledText {
            anchors.centerIn: parent
            visible: win.kind === "layout"
            width: parent.width - 32
            horizontalAlignment: Text.AlignHCenter
            text: win.layout
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
    }
}
