import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Components
import qs.Utils

// iOS-style dock: one icon per running app, centered at the bottom of each
// screen. Click focuses the app's most recent window. Hidden until the
// pointer reaches the bottom edge, then floats over the windows.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors.bottom: true // horizontally centered by the compositor
        readonly property int iconSize: 48
        // icon plates are ~22% rounded; concentric outer radius = inner + padding
        readonly property int pad: 10
        // stays up briefly after the pointer leaves, so small slips don't hide it
        property bool shown: false
        implicitWidth: glass.width
        implicitHeight: glass.height + Theme.gap
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "gshell-dock"
        WlrLayershell.layer: WlrLayer.Top
        // hidden: only a thin strip at the bottom edge catches the pointer
        // shown: the whole window (dock + gap below) keeps the hover, even while
        // the dock is still sliding in
        mask: Region { item: win.shown ? area : trigger }

        // most recently focused window per app class
        readonly property var apps: {
            const seen = {};
            for (const t of Hyprland.toplevels.values) {
                const ipc = t.lastIpcObject, cls = ipc?.class;
                if (!cls) continue;
                const best = seen[cls];
                if (!best || ipc.focusHistoryID < best.lastIpcObject.focusHistoryID) seen[cls] = t;
            }
            return Object.values(seen).sort((a, b) => a.lastIpcObject.class.localeCompare(b.lastIpcObject.class));
        }
        visible: apps.length > 0

        // right-click menu: the app's windows, its desktop actions, new window, quit
        function openMenu(icon) {
            const cls = icon.modelData.lastIpcObject.class;
            const entry = DesktopEntries.heuristicLookup(cls);
            const wins = Hyprland.toplevels.values.filter(t => t.lastIpcObject?.class === cls);
            const items = wins.map(t => ({ text: t.title || cls, act: () => t.wayland?.activate() }));
            if (entry) {
                items.push({ separator: true }, { text: "New Window", act: () => entry.execute() });
                for (const a of entry.actions) items.push({ text: a.name, act: () => a.execute() });
            }
            items.push({ separator: true },
                { text: wins.length > 1 ? "Quit All" : "Quit", act: () => wins.forEach(t => t.wayland?.close()) });
            const p = icon.mapToItem(null, icon.width / 2, 0);
            menu.openItems(items, win.offset.x + p.x - menu.implicitWidth / 2, win.offset.y + p.y - Theme.gap, true);
        }
        TrayMenu { id: menu; scr: win.modelData }
        // keep the dock up while its menu is open, hide after it closes
        Connections { target: menu; function onVisibleChanged() { if (!menu.visible) hide.restart() } }

        Backdrop {
            id: backdrop
            screen: win.modelData
            active: win.shown
        }
        readonly property point offset: Qt.point((screen.width - width) / 2, screen.height - height)

        Item { id: area; anchors.fill: parent }
        HoverHandler {
            id: hover
            onHoveredChanged: if (hovered) { hide.stop(); win.shown = true } else hide.restart()
        }
        Timer { id: hide; interval: 500; onTriggered: win.shown = menu.visible || hover.hovered }
        Item { id: trigger; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 3 }

        GlassSurface {
            id: glass
            backdrop: backdrop.texture
            offset: win.offset
            width: row.implicitWidth + win.pad * 2
            height: win.iconSize + win.pad * 2
            radius: Math.round(win.iconSize * 0.22) + win.pad
            // slide in from below the screen edge
            y: win.shown ? 0 : win.height
            moving: y
            opacity: win.shown ? 1 : 0
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            bevel: 14
            dispersion: 0
            blur: 4
            vibrancy: 0.6
            tint: Qt.rgba(0, 0, 0, 0.18)
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: win.pad
                Repeater {
                    model: win.apps
                    AppIcon {
                        id: app
                        required property var modelData
                        width: win.iconSize; height: win.iconSize
                        appId: modelData.lastIpcObject.class
                        scale: tap.pressed ? 0.88 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        TapHandler { id: tap; onTapped: app.modelData.wayland?.activate() }
                        TapHandler { acceptedButtons: Qt.RightButton; onTapped: win.openMenu(app) }
                        // running/focused indicator
                        Rectangle {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 2 }
                            width: 4; height: 4; radius: 2
                            color: Theme.fg
                            opacity: app.modelData.lastIpcObject.focusHistoryID === 0 ? 1 : 0.4
                        }
                    }
                }
            }
        }
    }
}
