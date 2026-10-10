import QtQuick
import qs.Utils

// Solid capsule that melts into liquid glass while `live` (held/dragged), like
// iOS 26 controls. Without a `wall` it just stays solid.
Item {
    id: root
    property bool live
    property color color: Qt.rgba(1, 1, 1, 0.92)
    property real radius: Math.min(width, height) / 2
    property var wall: null
    property point offset: Qt.point(0, 0)
    property real moving: 0
    // 0 solid .. 1 glass, springs a little past 1
    property real t: live && wall ? 1 : 0
    Behavior on t { SpringAnimation { spring: 4; damping: 0.35 } }
    readonly property bool glassy: t > 0.5

    // always rendered under the solid fill: showing a ShaderEffect while the
    // panel is open drops the Hyprland focus grab and closes it
    Loader {
        anchors.fill: parent
        active: root.wall !== null
        sourceComponent: GlassSurface {
            backdrop: root.wall
            offset: root.offset
            moving: root.moving + root.t + root.x + root.y + root.width + root.height
            radius: root.radius
            tint: Qt.rgba(1, 1, 1, 0.12)
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.color
        opacity: 1 - 0.8 * Math.max(0, Math.min(1, root.t))
    }
}
