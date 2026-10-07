import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.Utils

// Themed context menu for a tray item. Submenus open in place, with a back row.
PopupWindow {
    id: root
    property var menu: null // QsMenuHandle of the tray item
    property var stack: [] // submenu path, innermost last
    readonly property var current: stack.length ? stack[stack.length - 1] : menu
    readonly property int pad: 6
    readonly property int rowH: 26

    // x, y: in `window`, which must sit at the top-left of `scr` (the bar)
    required property var scr
    function open(m, window, x, y) {
        menu = m; stack = [];
        anchor.window = window;
        anchor.rect.x = x; anchor.rect.y = y;
        visible = true;
    }
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
        snapshot: true
    }

    GlassSurface {
        anchors.fill: parent
        backdrop: backdrop.texture
        offset: Qt.point(root.anchor.rect.x, root.anchor.rect.y)
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
                model: opener.children
                Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: modelData.isSeparator ? sep : row
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
                                modelData.triggered();
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
        readonly property bool on: entry ? entry.enabled : true
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
