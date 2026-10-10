import QtQuick
import qs.Utils

// iOS-style capsule slider, horizontal or `vertical` (fills from the bottom).
// Emits moved(v) with v in 0..1.
Item {
    id: root
    property real value: 0
    property string icon
    property bool vertical: false
    property real radius: Math.min(width, height) / 2
    // optional: with a backdrop the fill turns to liquid glass while dragged (iOS 26)
    property var wall: null
    property point offset: Qt.point(0, 0)
    property real moving: 0
    signal moved(real v)
    implicitWidth: vertical ? 56 : 200
    implicitHeight: vertical ? 140 : 28
    readonly property real v: Math.max(0, Math.min(root.value, 1))

    // swell while held, like the iOS 26 controls
    scale: 1 + 0.06 * fill.t

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.radius
        color: Theme.fill
        clip: true
        // fill never shrinks below a circle, so the round end stays round
        GlassKnob {
            id: fill
            live: ma.pressed
            wall: root.wall; offset: root.offset; moving: root.moving + root.scale
            readonly property real cap: Math.min(track.width, track.height)
            width: root.vertical ? track.width : Math.max(cap, track.width * root.v)
            height: root.vertical ? Math.max(cap, track.height * root.v) : track.height
            anchors.bottom: parent.bottom
            radius: track.radius
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !ma.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }


    Icon {
        x: 0
        y: root.vertical ? root.height - height - 6 : 0
        width: Math.min(root.width, root.height)
        height: root.vertical ? 30 : root.height
        text: root.icon
        font.pixelSize: root.vertical ? 18 : 13
        color: fill.glassy ? Theme.fg : "#1c1c1e"
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        function set(m) {
            const f = root.vertical ? 1 - m.y / height : m.x / width;
            root.moved(Math.max(0, Math.min(1, f)));
        }
        onPressed: m => set(m)
        onPositionChanged: m => set(m)
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + w.angleDelta.y / 2400)))
    }
}
