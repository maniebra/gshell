import QtQuick
import qs.Utils

// iOS-style segmented control. `options` is [{ label, value, icon? }]; emits
// picked(value). With a `wall` the pill turns to liquid glass while held and
// can be dragged across segments (iOS 26 tab bar).
Rectangle {
    id: seg
    property var options: []
    property var current
    property var wall: null
    property point offset: Qt.point(0, 0)
    property real moving: 0
    signal picked(var value)
    readonly property int inset: 2
    readonly property int idx: options.findIndex(o => o.value === current)
    readonly property real cell: width / Math.max(1, options.length)
    height: 28
    radius: height / 2 // capsule
    color: Theme.fill

    GlassKnob {
        id: pill
        visible: seg.idx >= 0 || ma.pressed
        live: ma.pressed
        wall: seg.wall; offset: seg.offset; moving: seg.moving
        width: seg.cell - seg.inset * 2
        height: seg.height - seg.inset * 2
        // follows the pointer while dragging, snaps to the segment otherwise
        x: ma.pressed ? Math.max(seg.inset, Math.min(seg.width - width - seg.inset, ma.mouseX - width / 2))
                      : seg.inset + Math.max(seg.idx, 0) * seg.cell
        y: seg.inset
        scale: 1 + 0.15 * t
        Behavior on x { enabled: !ma.pressed; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
    Row {
        anchors.fill: parent
        Repeater {
            model: seg.options
            Item {
                required property var modelData
                required property int index
                readonly property color ink: index === seg.idx && !pill.glassy ? "#1c1c1e" : Theme.fg
                width: seg.cell
                height: seg.height
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Icon {
                        visible: !!modelData.icon
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon ?? ""; font.pixelSize: 11
                        color: ink
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: modelData.icon ? 11 : 12
                        color: ink
                    }
                }
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        onReleased: m => {
            const i = Math.max(0, Math.min(seg.options.length - 1, Math.floor(m.x / seg.cell)));
            seg.picked(seg.options[i].value);
        }
    }
}
