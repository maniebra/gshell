import QtQuick
import qs.Utils

// macOS-style capsule slider. Emits moved(v) with v in 0..1.
Item {
    id: root
    property real value: 0
    property string icon
    signal moved(real v)
    implicitHeight: 28

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Theme.radiusControl
        color: Theme.fill
        Rectangle {
            width: Math.max(track.height, track.width * Math.min(root.value, 1))
            height: parent.height
            radius: track.radius
            color: Qt.rgba(1, 1, 1, 0.92)
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }

    Icon {
        x: 0; width: root.height; height: root.height
        text: root.icon
        font.pixelSize: 13
        color: "#1c1c1e"
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        function set(x) { root.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: m => set(m.x)
        onPositionChanged: m => set(m.x)
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + w.angleDelta.y / 2400)))
    }
}
