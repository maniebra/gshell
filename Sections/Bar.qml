import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects
import qs.Services
import qs.Components
import qs.Utils

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.barHeight + Theme.gap
        color: "transparent"
        WlrLayershell.namespace: "gshell-bar"

        Backdrop {
            id: backdrop
            screen: win.modelData
        }

        // progressive blur: frosted at the screen edge, clear toward the bottom
        ShaderEffect {
            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("../Shaders/fadeblur.frag.qsb")
            property var wall: backdrop.texture
            property size itemSize: Qt.size(width, height)
            property point itemPos: Qt.point(0, 0)
            property size screenSize: Qt.size(backdrop.texture.width, backdrop.texture.height)
            property real blur: 24
            property color tint: Qt.rgba(0, 0, 0, 0.25)
        }

        Item {
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.gap; rightMargin: Theme.gap }
            height: Theme.barHeight

            // workspace selector: dots, the active one stretches into a pill
            Row {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 6
                Repeater {
                    model: Hyprland.workspaces
                    Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.id === Hyprland.monitorFor(win.screen)?.activeWorkspace?.id
                        visible: modelData.id > 0 && modelData.monitor?.name === win.screen.name
                        width: active ? 20 : 8
                        height: 8
                        radius: 4
                        color: active ? Theme.fg : Theme.fgDim
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        TapHandler { onTapped: parent.modelData.activate() }
                    }
                }
            }

            // clock: transparent, shows album art and a live equalizer while
            // media plays. Hover: a black capsule with the track. Press and
            // hold: the expanded dynamic island (Island.qml).
            // Click: dashboard. Swipe left/right: next/previous track.
            // Swipe down: dashboard. Swipe up: play/pause.
            Item {
                id: notch
                readonly property var player: Player.current
                readonly property bool playing: player?.isPlaying ?? false
                anchors.horizontalCenter: parent.horizontalCenter
                // the expanded island replaces the capsule, never both
                readonly property bool open: hover.hovered && !ShellState.island
                width: island.width; height: parent.height
                Binding { target: Cava; property: "active"; value: notch.playing }
                HoverHandler { id: hover; onHoveredChanged: ShellState.islandHoverBar = hovered }

                Rectangle {
                    id: island
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 2
                    radius: height / 2
                    // follows the content, which already animates; only the
                    // padding animates here, so both move in the same frames
                    property real padX: notch.open ? 24 : 16
                    Behavior on padX { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                    width: content.implicitWidth + padX
                    onWidthChanged: if (notch.open) ShellState.islandFrom = width
                    color: "black"
                    opacity: notch.open ? 1 : 0
                    scale: notch.open ? 1 : 0.92
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
                    Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    // art and equalizer slide in/out: their slots grow from zero
                    // width (gap included) while they fade, so nothing pops

                    // album art
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: notch.playing ? 28 : 0
                        height: 18
                        clip: true
                        Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                        RoundedImage {
                            width: 18; height: 18; radius: 5
                            source: notch.player?.trackArtUrl ?? ""
                            opacity: notch.playing ? 1 : 0
                            scale: notch.playing ? 1 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 260 } }
                            Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                        }
                    }

                    // clock crossfades into the track while the capsule is open;
                    // the slot's width glides between the two
                    Item {
                        id: label
                        readonly property bool track: notch.open && notch.playing
                        anchors.verticalCenter: parent.verticalCenter
                        width: track ? title.width : clockText.implicitWidth
                        height: 18
                        clip: true // texts slide through the slot's edges
                        Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }

                        StyledText {
                            id: clockText
                            anchors.centerIn: parent
                            text: Time.time
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.2
                            // slides out upward as the track slides in from below
                            opacity: label.track ? 0 : 1
                            anchors.verticalCenterOffset: label.track ? -10 : 0
                            Behavior on opacity { NumberAnimation { duration: 240 } }
                            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                        }
                        SlideText {
                            id: title
                            anchors.centerIn: parent
                            maxWidth: 260
                            dir: Player.dir
                            text: (notch.player?.trackTitle ?? "") + (notch.player?.trackArtist ? "  ·  " + notch.player.trackArtist : "")
                            pixelSize: 12
                            weight: Font.DemiBold
                            width: implicitWidth
                            opacity: label.track ? 1 : 0
                            anchors.verticalCenterOffset: label.track ? 0 : 10
                            Behavior on opacity { NumberAnimation { duration: 240 } }
                            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                        }
                    }

                    // equalizer, driven by cava
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: notch.playing ? eqRow.implicitWidth + 10 : 0
                        height: 14
                        clip: true
                        Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                    Row {
                        id: eqRow
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        opacity: notch.playing ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                        spacing: 2
                        height: 14
                        Repeater {
                            model: 5
                            Rectangle {
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2.5; radius: 1.25
                                height: Math.max(3, 14 * (Cava.bars[index] ?? 0))
                                color: Theme.accent
                                Behavior on height { NumberAnimation { duration: 60 } }
                            }
                        }
                    }
                    }
                }

                MouseArea {
                    property real sx
                    property real sy
                    property bool done
                    anchors { fill: parent; margins: -6 }
                    pressAndHoldInterval: 350
                    onPressed: m => { sx = m.x; sy = m.y; done = false }
                    onPressAndHold: if (!done) { done = true; ShellState.island = true }
                    onPositionChanged: m => {
                        if (done) return;
                        const dx = m.x - sx, dy = m.y - sy;
                        // the bar is short and Hyprland stops motion once the pointer
                        // leaves it, so commit on small thresholds
                        if (Math.abs(dx) > 24) { done = true; dx > 0 ? Player.next() : Player.previous() }
                        else if (dy > 8) { done = true; ShellState.dashboard = true }
                        else if (dy < -6) { done = true; notch.player?.togglePlaying() }
                    }
                    onReleased: if (!done) ShellState.dashboard = !ShellState.dashboard
                }
            }

            // tray: click activates, right click (or a menu-only item) opens its menu
            Row {
                anchors { right: status.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 10
                Repeater {
                    model: SystemTray.items
                    // flattened to white silhouettes so every app matches the
                    // status glyphs, whatever colors its icon ships with
                    Image {
                        id: trayIcon
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15; height: 15
                        sourceSize: Qt.size(60, 60)
                        source: modelData.icon
                        smooth: true
                        mipmap: true
                        opacity: ma.pressed ? 0.6 : 1
                        layer.enabled: true
                        layer.textureSize: Qt.size(60, 60)
                        layer.mipmap: true
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            brightness: 1
                            colorization: 1
                            colorizationColor: Theme.fg
                        }
                        MouseArea {
                            id: ma
                            anchors { fill: parent; margins: -4 }
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: m => {
                                const it = trayIcon.modelData;
                                if (m.button === Qt.MiddleButton) it.secondaryActivate();
                                else if (m.button === Qt.RightButton || it.onlyMenu) {
                                    if (!it.hasMenu) return;
                                    const p = trayIcon.mapToItem(null, 0, trayIcon.height);
                                    trayMenu.open(it.menu, p.x - 8, p.y + 8); // bar sits at the screen's top-left
                                } else it.activate();
                            }
                            onWheel: w => trayIcon.modelData.scroll(w.angleDelta.y, false)
                        }
                    }
                }
            }
            TrayMenu { id: trayMenu; scr: win.screen }

            // status cluster, opens the control center
            Row {
                id: status
                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                spacing: 8
                Icon { anchors.verticalCenter: parent.verticalCenter; text: Network.wifiEnabled || Network.type === "ethernet" ? (Network.type === "ethernet" ? Icons.lan : Icons.wifi) : Icons.wifiOff; font.pixelSize: 15 }
                Icon { anchors.verticalCenter: parent.verticalCenter; text: Audio.muted ? Icons.volOff : Icons.vol; font.pixelSize: 15 }
                BatteryPill { anchors.verticalCenter: parent.verticalCenter; visible: Battery.available }
            }
            // click toggles; a short downward swipe opens. Hyprland stops sending
            // motion once the pointer leaves the bar, so the swipe commits as soon
            // as it crosses a small threshold instead of tracking the full pull.
            MouseArea {
                property real startY
                property bool swiped
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; left: status.left; leftMargin: -8 }
                onPressed: m => { startY = m.y; swiped = false }
                onPositionChanged: m => {
                    if (swiped || m.y - startY < 10) return;
                    swiped = true;
                    ShellState.controlCenter = true;
                }
                onReleased: if (!swiped) ShellState.controlCenter = !ShellState.controlCenter
            }
        }
    }
}
