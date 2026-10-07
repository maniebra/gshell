import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick
import qs.Services
import qs.Components
import qs.Utils

// macOS layout (tiles, wide sliders, expandable detail lists) with iOS
// controls (round toggles). Opens on the focused monitor under the bar.
PanelWindow {
    id: win
    readonly property int pad: Theme.padPanel
    // window starts at the bar's bottom edge so the glass grows out of it
    readonly property int lift: Theme.gap
    readonly property int tileW: 150
    readonly property var adapter: Bluetooth.defaultAdapter
    // which detail list is open: "", "wifi", "bt", "lan", "vpn"
    property string expanded: ""
    property string pwFor: ""
    // external output whose mode list is open
    property string modesFor: ""

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    // 0 closed .. 1 open, sprung
    property real progress: ShellState.controlCenter ? 1 : 0
    Behavior on progress {
        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
    }
    visible: progress > 0.002
    color: "transparent"
    WlrLayershell.namespace: "gshell-cc"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: Theme.gap + Theme.barHeight; right: Theme.gap }
    implicitWidth: tileW * 2 + pad * 3
    implicitHeight: body.height + pad * 2 + lift

    onVisibleChanged: if (visible) { Network.scan(); Brightness.refresh(); Monitors.refresh(); modesFor = ""; expanded = ""; pwFor = "" }

    HyprlandFocusGrab {
        windows: [win]
        active: ShellState.controlCenter
        onCleared: ShellState.controlCenter = false
    }

    Backdrop {
        id: backdrop
        screen: win.screen
        active: win.visible
        snapshot: true
    }
    readonly property point offset: Qt.point((screen?.width ?? 0) - width - margins.right, margins.top)

    LiquidGlass {
        backdrop: backdrop.texture
        offset: win.offset
        progress: win.progress
        lift: win.lift
        panelH: stage.height
        originX: 1
        bevel: 26
        blur: 3
        tint: Qt.rgba(0.02, 0.02, 0.04, 0.45)
        vibrancy: 0.6
    }
    mask: Region { item: stage }

    Item {
    id: stage
    y: win.lift; width: parent.width; height: parent.height - win.lift
    // content fades in once the drop has mostly formed
    opacity: Math.max(0, Math.min(1, (win.progress - 0.45) * 2.5))
    scale: 0.86 + 0.14 * win.progress
    transformOrigin: Item.TopRight
    transform: Translate { y: -24 * (1 - win.progress) }

    // one glass container holding every tile

    Column {
        id: body
        x: win.pad; y: win.pad
        width: win.tileW * 2 + win.pad
        spacing: win.pad
        focus: true
        Keys.onEscapePressed: ShellState.controlCenter = false

        // ── connectivity + media ──
        Row {
            spacing: win.pad

            Rectangle {

                radius: Theme.radiusTile; color: Theme.matte; border.color: Theme.matteBorder
                Grain { radius: parent.radius }
                transform: Translate { y: -14 * 1 * (1 - win.progress) }
                width: win.tileW; height: win.tileW
                Grid {
                    anchors.centerIn: parent
                    columns: 2; rowSpacing: 10; columnSpacing: 4
                    RoundToggle {
                        backdrop: backdrop.texture; offset: win.offset; moving: win.progress
                        icon: Network.wifiEnabled ? Icons.wifi : Icons.wifiOff
                        label: Network.type === "wifi" ? Network.name : "Wi-Fi"
                        active: Network.wifiEnabled
                        onToggled: Network.toggleWifi()
                        onExpand: win.expanded = win.expanded === "wifi" ? "" : "wifi"
                    }
                    RoundToggle {
                        backdrop: backdrop.texture; offset: win.offset; moving: win.progress
                        icon: win.adapter?.enabled ? Icons.bt : Icons.btOff
                        label: "Bluetooth"
                        active: win.adapter?.enabled ?? false
                        onToggled: if (win.adapter) win.adapter.enabled = !win.adapter.enabled
                        onExpand: win.expanded = win.expanded === "bt" ? "" : "bt"
                    }
                    RoundToggle {
                        backdrop: backdrop.texture; offset: win.offset; moving: win.progress
                        icon: Icons.lan
                        label: "Ethernet"
                        active: Network.wired.some(w => w.active)
                        onToggled: {
                            const w = Network.wired.find(w => w.active) ?? Network.wired[0];
                            if (w) Network.vpnToggle(w.name);
                        }
                        onExpand: win.expanded = win.expanded === "lan" ? "" : "lan"
                    }
                    RoundToggle {
                        backdrop: backdrop.texture; offset: win.offset; moving: win.progress
                        icon: Icons.vpn
                        label: Network.activeVpn?.name ?? "VPN"
                        active: Network.vpnUp
                        onToggled: {
                            const v = Network.activeVpn ?? Network.vpns[0];
                            if (v) Network.vpnToggle(v.name);
                        }
                        onExpand: win.expanded = win.expanded === "vpn" ? "" : "vpn"
                    }
                }
            }

            Rectangle {

                radius: Theme.radiusTile; color: Theme.matte; border.color: Theme.matteBorder
                Grain { radius: parent.radius }
                transform: Translate { y: -14 * 2 * (1 - win.progress) }
                id: media
                readonly property var p: Player.current
                width: win.tileW; height: win.tileW

                Image {
                    id: art
                    x: Theme.padTile; y: Theme.padTile
                    width: 52; height: 52
                    source: media.p?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                Icon {
                    x: Theme.padTile; y: Theme.padTile; width: 52; height: 52
                    visible: !art.visible
                    text: Icons.music
                    font.pixelSize: 30
                    color: Theme.fgDim
                }
                Column {
                    x: Theme.padTile; y: 76
                    width: parent.width - Theme.padTile * 2
                    StyledText {
                        width: parent.width
                        text: media.p?.trackTitle || "Not Playing"
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        width: parent.width
                        text: media.p?.trackArtist ?? ""
                        color: Theme.fgDim
                        font.pixelSize: 12
                    }
                }
                Row {
                    anchors { bottom: parent.bottom; bottomMargin: Theme.padTile; horizontalCenter: parent.horizontalCenter }
                    spacing: 6
                    Repeater {
                        model: [
                            { icon: Icons.prev, size: 22, act: () => Player.previous() },
                            { icon: media.p?.isPlaying ? Icons.pause : Icons.play, size: 30, act: () => media.p?.togglePlaying() },
                            { icon: Icons.next, size: 22, act: () => Player.next() }
                        ]
                        Icon {
                            required property var modelData
                            width: 42; height: 38
                            text: modelData.icon
                            font.pixelSize: modelData.size
                            opacity: media.p ? (ma.pressed ? 0.5 : 1) : 0.35
                            MouseArea { id: ma; anchors.fill: parent; onClicked: parent.modelData.act() }
                        }
                    }
                }
            }
        }

        // ── detail list for the expanded connection ──
        Rectangle {
            radius: Theme.radiusTile; color: Theme.matte; border.color: Theme.matteBorder
            Grain { radius: parent.radius }
            transform: Translate { y: -14 * 3 * (1 - win.progress) }
            width: parent.width
            height: win.expanded && win.expanded !== "display" ? Math.min(list.implicitHeight + Theme.padTile * 2, 300) : 0
            visible: height > 0
            clip: true
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Flickable {
                anchors { fill: parent; margins: Theme.padTile }
                contentHeight: list.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: list
                    width: parent.width
                    spacing: 2

                    Item {
                        width: parent.width; height: 28
                        StyledText {
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            text: ({ wifi: "Wi-Fi", bt: "Bluetooth", lan: "Ethernet", vpn: "VPN" })[win.expanded] ?? ""
                            font.weight: Font.Bold
                        }
                        Icon {
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            visible: win.expanded === "wifi" || win.expanded === "bt"
                            text: Icons.refresh
                            font.pixelSize: 15
                            color: (win.expanded === "bt" ? win.adapter?.discovering : Network.scanning) ? Theme.accent : Theme.fgDim
                            MouseArea {
                                anchors.fill: parent
                                onClicked: win.expanded === "bt"
                                    ? (win.adapter && (win.adapter.discovering = !win.adapter.discovering))
                                    : Network.scan()
                            }
                        }
                    }

                    // Wi-Fi
                    Repeater {
                        model: win.expanded === "wifi" ? Network.networks : []
                        ListRow {
                            required property var modelData
                            icon: Icons.wifi
                            text: modelData.ssid
                            active: modelData.active
                            trailing: modelData.active ? Icons.check : modelData.secured ? Icons.lock : ""
                            onClicked: {
                                if (modelData.active) return;
                                if (modelData.secured && !modelData.known) win.pwFor = modelData.ssid;
                                else Network.connect(modelData.ssid, "");
                            }
                        }
                    }
                    Rectangle {
                        visible: win.expanded === "wifi" && win.pwFor !== ""
                        width: parent.width; height: 34; radius: Theme.radiusControl
                        color: Theme.fill
                        TextInput {
                            id: pw
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 13
                            onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                            onAccepted: { Network.connect(win.pwFor, text); win.pwFor = "" }
                            StyledText {
                                visible: !parent.text
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password for " + win.pwFor
                                color: Theme.fgDim
                            }
                        }
                    }
                    StyledText {
                        visible: win.expanded === "wifi" && Network.error !== ""
                        width: parent.width
                        leftPadding: 8
                        text: Network.error
                        color: "#ff6961"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }

                    // Bluetooth
                    Repeater {
                        model: win.expanded === "bt" && win.adapter
                            ? win.adapter.devices.values.filter(d => d.name)
                                .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
                            : []
                        ListRow {
                            required property var modelData
                            icon: Icons.bt
                            text: modelData.name
                            active: modelData.connected
                            trailing: modelData.connected ? Icons.check
                                : modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                            onClicked: modelData.connected ? modelData.disconnect()
                                : modelData.paired ? modelData.connect() : modelData.pair()
                        }
                    }

                    // Ethernet / VPN (both are NM connections toggled up/down)
                    Repeater {
                        model: win.expanded === "lan" ? Network.wired : win.expanded === "vpn" ? Network.vpns : []
                        ListRow {
                            required property var modelData
                            icon: win.expanded === "lan" ? Icons.lan : Icons.vpn
                            text: modelData.name
                            active: modelData.active
                            trailing: modelData.active ? Icons.check : ""
                            onClicked: Network.vpnToggle(modelData.name)
                        }
                    }

                    StyledText {
                        visible: listEmpty()
                        function listEmpty() {
                            const e = win.expanded;
                            return e === "wifi" ? Network.networks.length === 0
                                 : e === "bt" ? !(win.adapter?.devices.values.some(d => d.name))
                                 : e === "lan" ? Network.wired.length === 0
                                 : e === "vpn" ? Network.vpns.length === 0 : false;
                        }
                        leftPadding: 8
                        text: "Nothing here"
                        color: Theme.fgDim
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ── displays ──
        Rectangle {
            radius: Theme.radiusTile; color: Theme.matte; border.color: Theme.matteBorder
            Grain { radius: parent.radius }
            transform: Translate { y: -14 * 4 * (1 - win.progress) }
            visible: Brightness.displays.length > 0 || Monitors.externals.length > 0
            width: parent.width; height: dispCol.implicitHeight + Theme.padTile * 2
            Column {
                id: dispCol
                x: Theme.padTile; y: Theme.padTile
                width: parent.width - Theme.padTile * 2
                spacing: 8
                Item {
                    width: parent.width; height: 16
                    StyledText { text: "Display"; font.weight: Font.DemiBold; font.pixelSize: 12 }
                    StyledText {
                        visible: Monitors.externals.length > 0
                        anchors.right: parent.right
                        text: win.expanded === "display" ? "Done" : "Arrange"
                        color: Theme.accent; font.pixelSize: 12
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: win.expanded = win.expanded === "display" ? "" : "display" }
                    }
                }
                Repeater {
                    model: Brightness.displays
                    Column {
                        required property var modelData
                        width: dispCol.width
                        spacing: 4
                        StyledText {
                            visible: Brightness.displays.length > 1
                            text: modelData.name; color: Theme.fgDim; font.pixelSize: 11
                        }
                        GlassSlider {
                            width: parent.width
                            value: modelData.value
                            icon: Icons.sun
                            // delegates are rebuilt on refresh, so breaking the binding here is fine
                            onMoved: v => { value = Math.max(v, 0.01); Brightness.set(modelData, value) }
                        }
                    }
                }

                // arrangement, collapsed behind the header toggle
                Column {
                    visible: win.expanded === "display"
                    width: dispCol.width
                    spacing: 6

                    // laptop panel on/off, only useful with something else plugged in
                    Row {
                        visible: Monitors.internal !== null && Monitors.externals.length > 0
                        spacing: 8
                        StyledText { width: 70; anchors.verticalCenter: parent.verticalCenter; text: "Built-in"; color: Theme.fgDim; font.pixelSize: 11 }
                        Segmented {
                            width: dispCol.width - 78
                            height: 24
                            options: [{ label: "On", value: false }, { label: "Off", value: true }]
                            current: Monitors.internal?.disabled ?? false
                            onPicked: v => v ? Monitors.setLayout(Monitors.internal, "off")
                                             : Monitors.apply(Monitors.internal, { disabled: false, mode: "preferred" })
                        }
                    }

                    Repeater {
                        model: Monitors.externals
                        Column {
                            id: ext
                            required property var modelData
                            readonly property string layout: Monitors.layoutOf(modelData)
                            readonly property bool extended: layout === "left" || layout === "right"
                            width: dispCol.width
                            spacing: 6
                            Row {
                                spacing: 8
                                StyledText {
                                    width: 70; anchors.verticalCenter: parent.verticalCenter
                                    text: ext.modelData.model || ext.modelData.name
                                    color: Theme.fgDim; font.pixelSize: 11
                                }
                                Segmented {
                                    width: dispCol.width - 78
                                    height: 24
                                    options: [{ label: "Left", value: "left" }, { label: "Right", value: "right" },
                                              { label: "Mirror", value: "mirror" }, { label: "Off", value: "off" }]
                                    current: ext.layout
                                    onPicked: v => Monitors.setLayout(ext.modelData, v)
                                }
                            }
                            // scale + mode share one line
                            Row {
                                visible: ext.layout !== "off"
                                spacing: 8
                                Segmented {
                                    id: scaleSeg
                                    visible: ext.extended
                                    width: (dispCol.width - 8) / 2
                                    height: 24
                                    options: [1, 1.5, 2].map(x => ({ label: x + "×", value: x }))
                                    current: ext.modelData.scale
                                    onPicked: v => Monitors.setScale(ext.modelData, v)
                                }
                                ListRow {
                                    width: ext.extended ? (dispCol.width - 8) / 2 : dispCol.width
                                    height: 24
                                    text: ext.modelData.width + "×" + ext.modelData.height + " " + Math.round(ext.modelData.refreshRate) + "Hz"
                                    trailing: win.modesFor === ext.modelData.name ? "▴" : "▾"
                                    onClicked: win.modesFor = win.modesFor === ext.modelData.name ? "" : ext.modelData.name
                                }
                            }
                            Flickable {
                                width: dispCol.width
                                height: Math.min(modeCol.implicitHeight, 150)
                                contentHeight: modeCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                Column {
                                    id: modeCol
                                    width: parent.width
                                    Repeater {
                                        model: win.modesFor === ext.modelData.name
                                            ? [...new Set(ext.modelData.availableModes)] : []
                                        ListRow {
                                            required property string modelData
                                            height: 28
                                            text: modelData.replace("@", "  ")
                                            active: modelData === Monitors.modeOf(ext.modelData)
                                            trailing: active ? Icons.check : ""
                                            onClicked: { Monitors.setMode(ext.modelData, modelData); win.modesFor = "" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── sound + microphone: one tile, mute rows on the left, tall sliders on the right ──
        Rectangle {
            radius: Theme.radiusTile; color: Theme.matte; border.color: Theme.matteBorder
            Grain { radius: parent.radius }
            transform: Translate { y: -14 * 4 * (1 - win.progress) }
            width: parent.width; height: 128

            readonly property var chans: [
                { label: "Sound", mic: false },
                { label: "Microphone", mic: true }
            ]
            function off(c) { return c.mic ? Audio.micMuted : Audio.muted }
            function level(c) { return c.mic ? Audio.micVolume : Audio.volume }

            Column {
                id: muteCol
                anchors { left: parent.left; leftMargin: Theme.padTile + 2; verticalCenter: parent.verticalCenter }
                spacing: 12
                Repeater {
                    model: parent.parent.chans
                    Row {
                        id: chRow
                        required property var modelData
                        readonly property var tile: muteCol.parent
                        spacing: 10
                        Rectangle {
                            width: 34; height: 34; radius: 17
                            color: chRow.tile.off(chRow.modelData) ? Theme.fill : Theme.accent
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Icon {
                                anchors.centerIn: parent; font.pixelSize: 14
                                text: chRow.modelData.mic ? (Audio.micMuted ? Icons.micOff : Icons.mic) : (Audio.muted ? Icons.volOff : Icons.vol)
                            }
                            MouseArea { anchors.fill: parent; onClicked: chRow.modelData.mic ? Audio.toggleMic() : Audio.toggleMute() }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: chRow.modelData.label; font.weight: Font.DemiBold; font.pixelSize: 12 }
                            StyledText {
                                text: chRow.tile.off(chRow.modelData) ? "Muted" : Math.round(chRow.tile.level(chRow.modelData) * 100) + "%"
                                color: Theme.fgDim; font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            Row {
                id: sliders
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; margins: Theme.padTile }
                spacing: Theme.padTile
                Repeater {
                    model: sliders.parent.chans
                    GlassSlider {
                        id: vs
                        required property var modelData
                        readonly property var tile: sliders.parent
                        vertical: true
                        width: 48; height: sliders.height
                        opacity: tile.off(modelData) ? 0.5 : 1
                        value: modelData.mic ? Audio.micVolume : (Audio.muted ? 0 : Audio.volume)
                        icon: modelData.mic ? Icons.mic : (Audio.muted || Audio.volume < 0.01 ? Icons.volOff : Icons.vol)
                        onMoved: v => {
                            if (vs.modelData.mic) Audio.setMicVolume(v);
                            else { if (Audio.muted) Audio.toggleMute(); Audio.setVolume(v) }
                        }
                    }
                }
            }
        }

        // ── power ──
        Rectangle {
            radius: Theme.radiusTile; color: Theme.matte; border.color: Theme.matteBorder
            Grain { radius: parent.radius }
            transform: Translate { y: -14 * 6 * (1 - win.progress) }
            width: parent.width; height: powerCol.implicitHeight + Theme.padTile * 2
            Column {
                id: powerCol
                x: Theme.padTile; y: Theme.padTile
                width: parent.width - Theme.padTile * 2
                spacing: 10

                Row {
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Battery.charging ? Icons.charging : Icons.battery
                        font.pixelSize: 15
                        color: Battery.low ? "#ff453a" : Battery.charging ? "#30d158" : Theme.fg
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Battery.available
                            ? Battery.percent + "%" + (Battery.remaining ? "  ·  " + Battery.remaining + (Battery.charging ? " to full" : " left") : "")
                            : "No battery"
                        font.weight: Font.DemiBold
                        font.pixelSize: 12
                    }
                }

                // segmented profile picker
                Rectangle {
                    id: seg
                    readonly property int inset: 2
                    readonly property var profiles: [
                        { p: PowerProfile.PowerSaver, icon: Icons.saver, name: "Saver" },
                        { p: PowerProfile.Balanced, icon: Icons.balanced, name: "Balanced" },
                        { p: PowerProfile.Performance, icon: Icons.performance, name: "Performance" }
                    ].filter(x => x.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                    width: parent.width; height: 32
                    radius: Theme.radiusControl
                    color: Theme.fill

                    Rectangle {
                        readonly property int idx: Math.max(0, seg.profiles.findIndex(x => x.p === PowerProfiles.profile))
                        width: seg.width / seg.profiles.length - seg.inset * 2
                        height: seg.height - seg.inset * 2
                        x: seg.inset + idx * seg.width / seg.profiles.length
                        y: seg.inset
                        radius: Theme.radiusControl - seg.inset
                        color: Qt.rgba(1, 1, 1, 0.9)
                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: seg.profiles
                            Item {
                                required property var modelData
                                readonly property bool on: PowerProfiles.profile === modelData.p
                                width: seg.width / seg.profiles.length
                                height: seg.height
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.icon; font.pixelSize: 12
                                        color: on ? "#1c1c1e" : Theme.fg
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name; font.pixelSize: 12
                                        color: on ? "#1c1c1e" : Theme.fg
                                    }
                                }
                                MouseArea { anchors.fill: parent; onClicked: PowerProfiles.profile = modelData.p }
                            }
                        }
                    }
                }
            }
        }
    }
    }
}
