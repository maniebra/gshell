import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Utils

// Themed glass context menu. Shows a tray item's menu (open), or plain
// entries [{ text, act, icon?, separator? }] (openItems). Submenus open in
// place, with a back row.
// A layer surface rather than a popup: Hyprland's focus grab (close on click
// elsewhere) works with these the same way as for the other panels.
PanelWindow {
    id: root
    property var menu: null // QsMenuHandle of the tray item
    property var stack: [] // submenu path, innermost last
    readonly property var current: stack.length ? stack[stack.length - 1] : menu
    readonly property int pad: 6
    readonly property int rowH: 26

    // x, y: screen-local position on `scr`
    required property var scr
    property var items: null // plain entries, used instead of `menu` when set
    // `above`: y is the menu's bottom edge (e.g. opening up from the dock)
    function openItems(list, x, y, above) { menu = null; stack = []; items = list; place(x, y, above) }
    function open(m, x, y) { menu = m; stack = []; items = null; place(x, y, false) }
    function place(x, y, above) { ax = x; ay = y; up = above; visible = true }
    // bound, not assigned: the height is only known once the rows are built
    property real ax; property real ay; property bool up
    margins.left: Math.max(Theme.gap, Math.min(ax, scr.width - implicitWidth - Theme.gap))
    margins.top: Math.max(Theme.gap, Math.min(up ? ay - implicitHeight : ay, scr.height - implicitHeight - Theme.gap))

    screen: scr
    visible: false
    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "gshell-traymenu"
    WlrLayershell.layer: WlrLayer.Overlay
    function close() { visible = false; stack = [] }

    implicitWidth: 230
    implicitHeight: col.implicitHeight + pad * 2
    color: "transparent"

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.close()
    }

    QsMenuOpener { id: opener; menu: root.current ?? null }

    Backdrop {
        id: backdrop
        screen: root.scr
        active: root.visible
    }

    GlassSurface {
        anchors.fill: parent
        backdrop: backdrop.texture
        offset: Qt.point(root.margins.left, root.margins.top)
        radius: Theme.radiusControl + root.pad // concentric with the rows
        bevel: 12
        blur: 6
        tint: Qt.rgba(0.02, 0.02, 0.04, 0.5)
        vibrancy: 0.6

        Column {
            id: col
            x: root.pad; y: root.pad
            width: parent.width - root.pad * 2

            // back to the parent menu
            Row_ {
                visible: root.stack.length > 0
                label: "‹  Back"
                onClicked: root.stack = root.stack.slice(0, -1)
            }

            Repeater {
                model: root.items ?? opener.children
                Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: modelData.isSeparator || modelData.separator ? sep : row
                    Component {
                        id: sep
                        Item { height: 9; Rectangle { anchors.centerIn: parent; width: parent.width - 12; height: 1; color: Theme.fill } }
                    }
                    Component {
                        id: row
                        Row_ {
                            entry: modelData
                            label: modelData.text.replace(/_(?=\w)/, "") // drop mnemonic underscores
                            onClicked: {
                                if (modelData.hasChildren) { root.stack = root.stack.concat([modelData]); return; }
                                if (modelData.act) modelData.act(); else modelData.triggered();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }

    component Row_: Rectangle {
        id: r
        property var entry: null
        property string label
        signal clicked
        width: col.width
        height: root.rowH
        radius: Theme.radiusControl
        readonly property bool on: entry?.enabled ?? true
        color: ma.containsMouse && on ? Theme.accent : "transparent"
        // checkbox / radio state
        StyledText {
            id: check
            x: 6; anchors.verticalCenter: parent.verticalCenter
            width: 14
            visible: r.entry?.buttonType > 0
            text: r.entry?.checkState === Qt.Checked ? "✓" : ""
            font.pixelSize: 12
        }
        Image {
            id: ico
            x: check.visible ? 22 : 8; anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            visible: (r.entry?.icon ?? "") !== ""
            source: r.entry?.icon ?? ""
            sourceSize: Qt.size(32, 32)
        }
        StyledText {
            anchors { left: ico.visible ? ico.right : (check.visible ? check.right : parent.left); leftMargin: 8; right: arrow.left; verticalCenter: parent.verticalCenter }
            text: r.label
            font.pixelSize: 12
            color: r.on ? Theme.fg : Theme.fgDim
        }
        StyledText {
            id: arrow
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: r.entry?.hasChildren ? "›" : ""
            color: Theme.fgDim
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: r.on; onClicked: r.clicked() }
    }
}
