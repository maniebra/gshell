import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import qs.Services
import qs.Components
import qs.Utils

// Dynamic island: press-and-hold on the bar clock morphs its capsule into an
// expanded card (now playing, or the date when nothing plays). Closes once
// the pointer leaves both the clock and the card.
PanelWindow {
    id: win
    readonly property var player: Player.current
    readonly property bool playing: player?.isPlaying ?? false
    readonly property int pad: 16
    readonly property int artSize: 64
    readonly property bool open: ShellState.island
    readonly property bool hovered: ShellState.islandHoverBar || ShellState.islandHoverCard
    // 0 capsule .. 1 card
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }

    // close after a short grace once the pointer is off both, so moving from
    // the clock into the card doesn't close it
    onHoveredChanged: if (hovered) closer.stop(); else if (open) closer.restart()
    onOpenChanged: if (open && !hovered) closer.restart()
    Timer { id: closer; interval: 400; onTriggered: ShellState.island = false }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    visible: progress > 0.01
    color: "transparent"
    WlrLayershell.namespace: "gshell-island"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true // horizontally centered by the compositor
    implicitWidth: 380
    implicitHeight: 160
    mask: Region { item: card }

    // 0..1 ramp of `t` between a and b, for staggering parts of the morph
    function ramp(t, a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))) }
    function lerp(a, b, t) { return a + (b - a) * t }

    Rectangle {
        id: card
        readonly property real p: Math.max(0, win.progress)
        readonly property real fromW: Math.max(60, ShellState.islandFrom)
        readonly property real fromH: Theme.barHeight - 2
        // morph from the bar's hover capsule to the full card
        width: win.lerp(fromW, parent.width - 8, p)
        height: win.lerp(fromH, parent.height - 8, Math.min(1, p))
        x: (parent.width - width) / 2
        y: win.lerp(1, 4, p)
        radius: Math.min(height / 2, 12 + win.pad) // concentric with the art corners when open
        color: "black"
        opacity: Math.min(1, win.progress * 6)
        clip: true

        HoverHandler { onHoveredChanged: ShellState.islandHoverCard = hovered }

        // ── now playing: art and equalizer fly from their spots in the capsule
        // to the card; texts and controls slide in after ──
        Item {
            anchors.fill: parent
            visible: win.player !== null
            readonly property real m: Math.min(1, card.p)

            RoundedImage {
                id: art
                width: win.lerp(18, win.artSize, parent.m); height: width
                radius: win.lerp(5, 12, parent.m)
                x: win.lerp(12, win.pad, parent.m)
                y: win.lerp((card.fromH - 18) / 2, win.pad, parent.m)
                source: Player.artUrl
            }
            Row {
                id: eq
                readonly property real h: win.lerp(14, 20, parent.m)
                x: card.width - width - win.lerp(12, win.pad, parent.m)
                y: win.lerp((card.fromH - 14) / 2, win.pad + 4, parent.m)
                spacing: win.lerp(2, 2.5, parent.m)
                height: h
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: win.lerp(2.5, 3, eq.parent.m); radius: width / 2
                        height: Math.max(3, eq.h * (win.playing ? (Cava.bars[index] ?? 0) : 0))
                        color: Theme.accent
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }

            Column {
                readonly property real t: win.ramp(card.p, 0.35, 0.85)
                x: art.x + art.width + 12
                width: eq.x - x - 8
                y: art.y + (art.height - height) / 2 + 10 * (1 - t)
                opacity: t
                spacing: 2
                SlideText { maxWidth: parent.width; dir: Player.dir; text: win.player?.trackTitle || "Not Playing"; pixelSize: 15; weight: Font.DemiBold }
                SlideText { maxWidth: parent.width; dir: Player.dir; text: win.player?.trackArtist ?? ""; color: Theme.fgDim }
            }

            // scrubber + controls
            Timer {
                interval: 1000; repeat: true
                running: win.visible && win.playing
                onTriggered: win.player?.positionChanged()
            }
            Item {
                readonly property real t: win.ramp(card.p, 0.5, 0.95)
                id: scrub
                x: win.pad; width: card.width - win.pad * 2
                y: win.pad + win.artSize + 12 + 14 * (1 - t)
                opacity: t
                height: 5
                visible: (win.player?.length ?? 0) > 0
                Rectangle { anchors.fill: parent; radius: 2.5; color: Theme.fill }
                Rectangle {
                    width: parent.width * Math.min(1, (win.player?.position ?? 0) / Math.max(1, win.player?.length ?? 1))
                    height: parent.height; radius: 2.5; color: Theme.fg
                }
                MouseArea {
                    anchors { fill: parent; margins: -6 }
                    enabled: win.player?.canSeek ?? false
                    onClicked: m => win.player.position = win.player.length * Math.max(0, Math.min(1, m.x / width))
                }
            }
            Row {
                readonly property real t: win.ramp(card.p, 0.6, 1)
                anchors.horizontalCenter: parent.horizontalCenter
                y: card.height - height - win.pad + 6 + 18 * (1 - t)
                opacity: t
                spacing: 18
                Repeater {
                    model: [
                        { icon: Icons.prev, size: 18, act: () => Player.previous() },
                        { icon: win.playing ? Icons.pause : Icons.play, size: 24, act: () => win.player?.togglePlaying() },
                        { icon: Icons.next, size: 18, act: () => Player.next() }
                    ]
                    Icon {
                        required property var modelData
                        width: 40; height: 32
                        text: modelData.icon
                        font.pixelSize: modelData.size
                        opacity: ma.pressed ? 0.5 : 1
                        MouseArea { id: ma; anchors.fill: parent; onClicked: parent.modelData.act() }
                    }
                }
            }
        }

        Item {
            anchors { fill: parent; margins: win.pad }
            opacity: win.ramp(card.p, 0.4, 0.9)

            // ── nothing playing: date ──
            Column {
                anchors.centerIn: parent
                visible: win.player === null
                spacing: 2
                SystemClock { id: clock; precision: SystemClock.Minutes }
                StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(clock.date, "hh:mm"); font.pixelSize: 40; font.weight: Font.Light }
                StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(clock.date, "dddd, d MMMM"); color: Theme.fgDim }
            }
        }
    }
}
