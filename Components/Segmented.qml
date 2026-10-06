import QtQuick
import qs.Utils

// macOS segmented control. `options` is [{ label, value }]; emits picked(value).
Rectangle {
    id: seg
    property var options: []
    property var current
    signal picked(var value)
    readonly property int inset: 2
    readonly property int idx: options.findIndex(o => o.value === current)
    height: 28
    radius: Theme.radiusControl
    color: Theme.fill

    Rectangle {
        visible: seg.idx >= 0
        width: seg.width / seg.options.length - seg.inset * 2
        height: seg.height - seg.inset * 2
        x: seg.inset + Math.max(seg.idx, 0) * seg.width / seg.options.length
        y: seg.inset
        radius: Theme.radiusControl - seg.inset
        color: Qt.rgba(1, 1, 1, 0.9)
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
    Row {
        anchors.fill: parent
        Repeater {
            model: seg.options
            StyledText {
                required property var modelData
                required property int index
                width: seg.width / seg.options.length
                height: seg.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.label
                font.pixelSize: 12
                color: index === seg.idx ? "#1c1c1e" : Theme.fg
                MouseArea { anchors.fill: parent; onClicked: seg.picked(parent.modelData.value) }
            }
        }
    }
}
