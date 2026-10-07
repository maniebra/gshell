import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.Services
import qs.Components
import qs.Utils

// iPadOS-style widget board: media, calendar, system metrics. Opens under the
// bar's clock on the focused monitor.
PanelWindow {
    id: win
    readonly property int pad: Theme.padPanel
    // window starts at the bar's bottom edge so the glass grows out of it
    readonly property int lift: Theme.gap
    readonly property int colW: 340
    readonly property int calW: 300
    readonly property int tileH: 170
    readonly property int tabH: 28 + pad
    property int tab: 0 // 0 overview, 1 notifications, 2 appearance

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    property real progress: ShellState.dashboard ? 1 : 0
    Behavior on progress {
        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
    }
    visible: progress > 0.002
    color: "transparent"
    WlrLayershell.namespace: "gshell-dash"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true // horizontally centered by the compositor
    margins.top: Theme.gap + Theme.barHeight
    implicitWidth: colW + calW + pad * 3
    implicitHeight: tileH * 2 + pad * 3 + tabH + lift
    mask: Region { item: stage }

    onVisibleChanged: if (visible) { cal.month = new Date(); tab = 0 }
    Binding { target: SysStats; property: "active"; value: win.visible }

    HyprlandFocusGrab {
        windows: [win]
        active: ShellState.dashboard
        onCleared: ShellState.dashboard = false
    }

    Backdrop {
        id: backdrop
        screen: win.screen
        active: win.visible
        snapshot: true
    }
    readonly property point offset: Qt.point(((screen?.width ?? 0) - width) / 2, margins.top)

    // matte grey tiles with grain, same as the control center
    component Tile: Rectangle {
        radius: Theme.radiusTile
        color: Theme.matte
        border.color: Theme.matteBorder
        Grain { radius: parent.radius }
    }

    // "From Cover Art" switch: take hue + saturation from the playing cover art
    component ArtSwitch: Row {
        id: sw
        property bool on
        signal toggled
        spacing: 6
        StyledText { anchors.verticalCenter: parent.verticalCenter; text: "From Cover Art"; font.pixelSize: 11; color: Theme.fgDim }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 18; radius: 9
            color: sw.on ? Theme.accent : Theme.fill
            Behavior on color { ColorAnimation { duration: 160 } }
            Rectangle {
                width: 14; height: 14; radius: 7; y: 2
                x: sw.on ? parent.width - width - 2 : 2
                color: "white"
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors { fill: parent; margins: -4 } onClicked: sw.toggled() }
        }
    }

    component Caption: StyledText {
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        color: Qt.rgba(1, 1, 1, 0.75)
    }

    // circular gauge, iPadOS battery-widget style
    component Ring: Item {
        id: ring
        property real value: 0
        property color tint: Theme.accent
        property string label
        property string text
        width: 64; height: 86
        Shape {
            width: 64; height: 64
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: Theme.fill; strokeWidth: 6; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 32; centerY: 32; radiusX: 28; radiusY: 28; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: ring.tint; strokeWidth: 6; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 32; centerY: 32; radiusX: 28; radiusY: 28; startAngle: -90
                    sweepAngle: 360 * Math.max(0.001, Math.min(1, ring.value))
                    Behavior on sweepAngle { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
            }
        }
        StyledText {
            width: 64; height: 64
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: ring.text
            font.pixelSize: 14; font.weight: Font.DemiBold
        }
        Caption { anchors.bottom: parent.bottom; width: 64; horizontalAlignment: Text.AlignHCenter; text: ring.label }
    }

    LiquidGlass {
        backdrop: backdrop.texture
        offset: win.offset
        progress: win.progress
        lift: win.lift
        panelH: stage.height
        originX: 0.5
        bevel: 26
        blur: 3
        tint: Qt.rgba(0.02, 0.02, 0.04, 0.45)
        vibrancy: 0.6
    }

    Item {
        id: stage
        y: win.lift; width: parent.width; height: parent.height - win.lift
        // content fades in once the drop has mostly formed
        opacity: Math.max(0, Math.min(1, (win.progress - 0.45) * 2.5))
        scale: 0.86 + 0.14 * win.progress
        transformOrigin: Item.Top
        transform: Translate { y: -24 * (1 - win.progress) }
        focus: true
        Keys.onEscapePressed: ShellState.dashboard = false

        Segmented {
            x: win.pad; y: win.pad
            width: 330
            anchors.horizontalCenter: parent.horizontalCenter
            options: [{ label: "Overview", value: 0 }, { label: "Notifications" + (Notifs.list.length ? ` (${Notifs.list.length})` : ""), value: 1 }, { label: "Appearance", value: 2 }]
            current: win.tab
            onPicked: v => win.tab = v
        }

        // ── appearance ──
        Item {
            y: win.tabH; width: parent.width; height: parent.height - win.tabH
            readonly property int page: 2
            x: (page - win.tab) * 48
            opacity: win.tab === page ? 1 : 0
            visible: opacity > 0
            enabled: win.tab === page
            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 220 } }

            Tile {
                x: win.pad; y: win.pad
                width: parent.width - win.pad * 2; height: 168
                Caption { x: Theme.padTile + 4; y: Theme.padTile; text: "App Icons" }
                ArtSwitch {
                    anchors { right: parent.right; rightMargin: Theme.padTile + 4; top: parent.top; topMargin: Theme.padTile - 2 }
                    on: ShellState.iconTintFromArt
                    onToggled: ShellState.iconTintFromArt = !ShellState.iconTintFromArt
                }
                // live preview of the picked style
                Row {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 34 }
                    spacing: 14
                    Repeater {
                        model: ["firefox", "org.gnome.Nautilus", "spotify", "kitty", "code"]
                        AppIcon { required property string modelData; appId: modelData; width: 32; height: 32 }
                    }
                }
                // tint color, used by the "tinted" style
                Row {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: styles.top; bottomMargin: 12 }
                    spacing: 10
                    opacity: ShellState.iconStyle === "tinted" ? 1 : 0.35
                    Repeater {
                        model: ["#ffd60a", "#ff9f0a", "#ff453a", "#ff375f", "#bf5af2", "#5e5ce6", "#0a84ff", "#64d2ff", "#30d158", "#ffffff"]
                        Rectangle {
                            required property string modelData
                            readonly property bool picked: Qt.colorEqual(ShellState.iconTint, modelData)
                            width: 20; height: 20; radius: 10
                            antialiasing: true
                            color: modelData
                            border { width: picked ? 2 : 0; color: Theme.fg }
                            scale: picked ? 1.15 : 1
                            Behavior on scale { NumberAnimation { duration: 150 } }
                            MouseArea {
                                anchors { fill: parent; margins: -3 }
                                onClicked: { ShellState.iconTint = parent.modelData; ShellState.iconStyle = "tinted" }
                            }
                        }
                    }
                }
                Segmented {
                    id: styles
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.padTile }
                    options: [{ label: "Default", value: "default" }, { label: "Dark", value: "dark" }, { label: "Clear", value: "clear" }, { label: "Tinted", value: "tinted" }]
                    current: ShellState.iconStyle
                    onPicked: v => ShellState.iconStyle = v
                }
            }

            Tile {
                x: win.pad; y: win.pad * 2 + 168
                width: parent.width - win.pad * 2; height: 64
                Caption { x: Theme.padTile + 4; y: Theme.padTile; text: "Accent Color" }
                ArtSwitch {
                    anchors { right: parent.right; rightMargin: Theme.padTile + 4; top: parent.top; topMargin: Theme.padTile - 2 }
                    on: ShellState.accentFromArt
                    onToggled: ShellState.accentFromArt = !ShellState.accentFromArt
                }
                Row {
                    anchors { right: parent.right; rightMargin: Theme.padTile + 4; top: parent.top; topMargin: Theme.padTile - 2 }
                    spacing: 6
                    StyledText { anchors.verticalCenter: parent.verticalCenter; text: "From Cover Art"; font.pixelSize: 11; color: Theme.fgDim }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 18; radius: 9
                        color: ShellState.accentFromArt ? Theme.accent : Theme.fill
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Rectangle {
                            width: 14; height: 14; radius: 7; y: 2
                            x: ShellState.accentFromArt ? parent.width - width - 2 : 2
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors { fill: parent; margins: -4 } onClicked: ShellState.accentFromArt = !ShellState.accentFromArt }
                    }
                }
                Row {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.padTile + 2 }
                    spacing: 12
                    Repeater {
                        model: ["#0a84ff", "#5e5ce6", "#bf5af2", "#ff375f", "#ff453a", "#ff9f0a", "#ffd60a", "#30d158", "#64d2ff", "#8e8e93"]
                        Rectangle {
                            required property string modelData
                            readonly property bool picked: Qt.colorEqual(ShellState.accent, modelData)
                            width: 20; height: 20; radius: 10
                            antialiasing: true
                            color: modelData
                            border { width: picked ? 2 : 0; color: Theme.fg }
                            scale: picked ? 1.15 : 1
                            Behavior on scale { NumberAnimation { duration: 150 } }
                            // with cover-art sampling on, the pick only sets lightness
                            MouseArea { anchors { fill: parent; margins: -3 } onClicked: ShellState.accent = parent.modelData }
                        }
                    }
                }
            }
        }

        // ── notifications ──
        Item {
            y: win.tabH; width: parent.width; height: parent.height - win.tabH
            // slide + fade toward the picked tab's side
            readonly property int page: 1
            x: (page - win.tab) * 48
            opacity: win.tab === page ? 1 : 0
            visible: opacity > 0
            enabled: win.tab === page
            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 220 } }

            StyledText {
                anchors.centerIn: parent
                visible: Notifs.list.length === 0
                text: "No notifications"
                color: Theme.fgDim
            }
            StyledText {
                anchors { right: parent.right; rightMargin: win.pad + 4; top: parent.top }
                visible: Notifs.list.length > 0
                text: "Clear all"
                font.pixelSize: 12
                color: Theme.accent
                MouseArea { anchors.fill: parent; onClicked: Notifs.clear() }
            }
            ListView {
                anchors { fill: parent; margins: win.pad; topMargin: 22 }
                spacing: win.pad
                clip: true
                model: Notifs.list
                delegate: Tile {
                    required property var modelData
                    width: ListView.view.width
                    height: col.height + Theme.padTile * 2
                    Column {
                        id: col
                        x: Theme.padTile; y: Theme.padTile
                        width: parent.width - Theme.padTile * 2
                        spacing: 2
                        Caption { text: modelData.appName }
                        StyledText { width: parent.width; text: modelData.summary; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        StyledText { width: parent.width; text: modelData.body; color: Theme.fgDim; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; visible: text !== "" }
                    }
                    // click runs the default action if any, then dismisses
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modelData.actions.find(a => a.identifier === "default")?.invoke();
                            modelData.dismiss();
                        }
                    }
                }
            }
        }

        Item {
        id: overview
        y: win.tabH; width: parent.width; height: parent.height - win.tabH
        // slide + fade toward the picked tab's side
        readonly property int page: 0
        x: (page - win.tab) * 48
        opacity: win.tab === page ? 1 : 0
        visible: opacity > 0
        enabled: win.tab === page
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220 } }

        // ── media ──
        Tile {
            id: media
            readonly property var p: Player.current
            x: win.pad; y: win.pad
            width: win.colW; height: win.tileH
            clip: true
            transform: Translate { y: -14 * (1 - win.progress) }

            // poll position while playing; Mpris only signals on seek
            Timer {
                interval: 1000; repeat: true
                running: win.visible && (media.p?.isPlaying ?? false)
                onTriggered: media.p?.positionChanged()
            }

            Rectangle {
                id: artBox
                x: Theme.padTile; y: Theme.padTile
                width: 92; height: 92
                radius: Theme.radiusControl
                color: Theme.fill
                Image {
                    id: art
                    anchors.fill: parent
                    source: media.p?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }
                Rectangle { id: mask; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
                Icon {
                    anchors.fill: parent
                    visible: art.status !== Image.Ready
                    text: Icons.music; font.pixelSize: 36; color: Theme.fgDim
                }
            }

            Column {
                anchors { left: artBox.right; leftMargin: 14; right: parent.right; rightMargin: Theme.padTile; top: artBox.top; topMargin: 6 }
                spacing: 2
                Caption { text: media.p?.identity ?? "Music" }
                StyledText {
                    width: parent.width
                    text: media.p?.trackTitle || "Not Playing"
                    font.pixelSize: 16; font.weight: Font.DemiBold
                }
                StyledText {
                    width: parent.width
                    text: media.p?.trackArtist ?? ""
                    color: Theme.fgDim
                }
            }

            Row {
                anchors { left: artBox.right; leftMargin: 6; bottom: artBox.bottom }
                spacing: 4
                Repeater {
                    model: [
                        { icon: Icons.prev, size: 20, act: () => Player.previous() },
                        { icon: media.p?.isPlaying ? Icons.pause : Icons.play, size: 26, act: () => media.p?.togglePlaying() },
                        { icon: Icons.next, size: 20, act: () => Player.next() }
                    ]
                    Icon {
                        required property var modelData
                        width: 44; height: 36
                        text: modelData.icon
                        font.pixelSize: modelData.size
                        opacity: media.p ? (ma.pressed ? 0.5 : 1) : 0.35
                        MouseArea { id: ma; anchors.fill: parent; onClicked: parent.modelData.act() }
                    }
                }
            }

            // scrubber
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.padTile }
                height: 28
                visible: (media.p?.length ?? 0) > 0
                readonly property real frac: media.p?.length > 0 ? media.p.position / media.p.length : 0
                function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
                Rectangle {
                    id: bar
                    width: parent.width; height: 5; radius: 2.5
                    color: Theme.fill
                    Rectangle { width: parent.width * Math.min(1, parent.parent.frac); height: parent.height; radius: parent.radius; color: Theme.fg }
                }
                StyledText { anchors { left: parent.left; bottom: parent.bottom } text: parent.fmt(media.p?.position ?? 0); font.pixelSize: 10; color: Theme.fgDim }
                StyledText { anchors { right: parent.right; bottom: parent.bottom } text: "-" + parent.fmt((media.p?.length ?? 0) - (media.p?.position ?? 0)); font.pixelSize: 10; color: Theme.fgDim }
                MouseArea {
                    anchors.fill: parent
                    enabled: media.p?.canSeek ?? false
                    onClicked: m => media.p.position = media.p.length * Math.max(0, Math.min(1, m.x / width))
                }
            }
        }

        // ── metrics ──
        Tile {
            x: win.pad; y: win.pad * 2 + win.tileH
            width: win.colW; height: win.tileH
            transform: Translate { y: -28 * (1 - win.progress) }

            Caption { x: Theme.padTile + 4; y: Theme.padTile; text: "System" }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.padTile + 4 }
                spacing: 16
                Ring { label: "CPU"; value: SysStats.cpu; tint: "#0a84ff"; text: Math.round(SysStats.cpu * 100) + "%" }
                Ring { label: "Memory"; value: SysStats.mem; tint: "#30d158"; text: SysStats.memUsedGb.toFixed(1) }
                Ring { label: "Disk"; value: SysStats.disk; tint: "#ff9f0a"; text: Math.round(SysStats.disk * 100) + "%" }
                Ring { label: "Temp"; value: SysStats.temp / 100; tint: SysStats.temp > 80 ? "#ff453a" : "#bf5af2"; text: Math.round(SysStats.temp) + "°" }
            }
        }

        // ── calendar ──
        Tile {
            id: cal
            property date month: new Date()
            readonly property date today: clock.date
            x: win.pad * 2 + win.colW; y: win.pad
            width: win.calW; height: win.tileH * 2 + win.pad
            transform: Translate { y: -21 * (1 - win.progress) }

            SystemClock { id: clock; precision: SystemClock.Hours }

            function shift(n) { month = new Date(month.getFullYear(), month.getMonth() + n, 1) }

            StyledText {
                x: Theme.padTile + 4; y: Theme.padTile
                text: Qt.formatDate(cal.today, "dddd").toUpperCase()
                color: "#ff453a"; font.pixelSize: 12; font.weight: Font.DemiBold
            }
            StyledText {
                x: Theme.padTile + 4; y: Theme.padTile + 16
                text: Qt.formatDate(cal.today, "d")
                font.pixelSize: 40; font.weight: Font.Light
            }

            Row {
                id: head
                x: Theme.padTile + 4; y: 80
                width: parent.width - (Theme.padTile + 4) * 2
                StyledText {
                    width: parent.width - 56
                    text: Qt.formatDate(cal.month, "MMMM yyyy")
                    font.pixelSize: 15; font.weight: Font.DemiBold
                }
                Repeater {
                    model: [{ t: "‹", n: -1 }, { t: "›", n: 1 }]
                    StyledText {
                        required property var modelData
                        width: 28; horizontalAlignment: Text.AlignHCenter
                        text: modelData.t; font.pixelSize: 20; color: Theme.accent
                        MouseArea { anchors.fill: parent; onClicked: cal.shift(parent.modelData.n) }
                    }
                }
            }

            Grid {
                id: grid
                anchors { horizontalCenter: parent.horizontalCenter; top: head.bottom; topMargin: 10 }
                columns: 7
                readonly property int cell: 38
                // Monday-first
                readonly property int lead: (new Date(cal.month.getFullYear(), cal.month.getMonth(), 1).getDay() + 6) % 7
                readonly property int days: new Date(cal.month.getFullYear(), cal.month.getMonth() + 1, 0).getDate()

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Caption { required property string modelData; width: grid.cell; height: 22; horizontalAlignment: Text.AlignHCenter; text: modelData }
                }
                Repeater {
                    model: 42
                    Item {
                        required property int index
                        readonly property int day: index - grid.lead + 1
                        readonly property bool isToday: day === cal.today.getDate()
                            && cal.month.getMonth() === cal.today.getMonth()
                            && cal.month.getFullYear() === cal.today.getFullYear()
                        width: grid.cell; height: 32
                        visible: day >= 1 && day <= grid.days || index < 35
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28; height: 28; radius: 14
                            color: "#ff453a"
                            visible: parent.isToday
                        }
                        StyledText {
                            anchors.centerIn: parent
                            text: parent.day >= 1 && parent.day <= grid.days ? parent.day : ""
                            font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                            color: (parent.index % 7) >= 5 && !parent.isToday ? Theme.fgDim : Theme.fg
                        }
                    }
                }
            }

            WheelHandler { onWheel: e => cal.shift(e.angleDelta.y > 0 ? -1 : 1) }
        }
        }
    }
}
