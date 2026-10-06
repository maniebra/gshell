import QtQuick
import qs.Utils

// iOS-style circular toggle. Click/tap toggles; right-click, long-press or
// clicking the label asks for details (expand).
Column {
    id: root
    property bool active
    property string icon
    property string label
    required property var backdrop
    property point offset
    property real moving
    signal toggled
    signal expand
    spacing: 5
    width: 78

    GlassSurface {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 46; height: 46; radius: Theme.radiusControl + 4 // squircle-ish tile, not a circle
        backdrop: root.backdrop
        offset: root.offset
        moving: root.moving + scale
        bevel: 10
        tint: Qt.rgba(1, 1, 1, 0.08)
        scale: ma.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }

        // accent wash when on; glass shows through
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Theme.accent
            opacity: root.active ? 0.85 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Icon { anchors.centerIn: parent; text: root.icon; font.pixelSize: 20 }

        MouseArea {
            id: ma
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? root.expand() : root.toggled()
            onPressAndHold: root.expand()
        }
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        font.pixelSize: 11
        color: Theme.fgDim
        MouseArea { anchors.fill: parent; onClicked: root.expand() }
    }
}
