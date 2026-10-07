import QtQuick
import qs.Utils

// Text that slides horizontally when it changes: the old text leaves toward
// -dir and the new one enters from +dir (dir 1 = next, -1 = previous).
Item {
    id: root
    property string text
    property int dir: 1
    property int pixelSize: 13
    property int weight: Font.Normal
    property color color: Theme.fg
    property real maxWidth: 1e6
    implicitWidth: Math.min(maxWidth, (flip ? b : a).implicitWidth)
    implicitHeight: a.implicitHeight
    clip: true

    property bool flip: false // which label currently shows the text
    property string textA: text
    property string textB: ""
    readonly property int dur: 360

    onTextChanged: {
        if (flip) textA = text; else textB = text;
        flip = !flip;
        anim.restart();
    }

    component Label: StyledText {
        width: Math.min(implicitWidth, root.maxWidth)
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        color: root.color
    }
    Label { id: a; text: root.textA }
    Label { id: b; text: root.textB; opacity: 0 }

    ParallelAnimation {
        id: anim
        readonly property Item inc: root.flip ? b : a
        readonly property Item out: root.flip ? a : b
        NumberAnimation { target: anim.inc; property: "x"; from: root.dir * 40; to: 0; duration: root.dur; easing.type: Easing.OutCubic }
        NumberAnimation { target: anim.inc; property: "opacity"; from: 0; to: 1; duration: root.dur }
        NumberAnimation { target: anim.out; property: "x"; to: -root.dir * 40; duration: root.dur; easing.type: Easing.OutCubic }
        NumberAnimation { target: anim.out; property: "opacity"; to: 0; duration: root.dur * 0.7 }
    }
}
