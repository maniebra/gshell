import QtQuick
import qs.Utils

Rectangle {
    id: root
    property string icon
    property string text
    property string trailing
    property bool active
    signal clicked
    width: parent?.width ?? 0
    height: 34
    radius: Theme.radiusControl
    color: ma.containsMouse ? Theme.fill : "transparent"

    Icon {
        id: ic
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        width: 22
        text: root.icon
        font.pixelSize: 16
        color: root.active ? Theme.accent : Theme.fg
    }
    StyledText {
        anchors { left: ic.right; leftMargin: 8; right: tr.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        text: root.text
        font.weight: root.active ? Font.DemiBold : Font.Normal
    }
    Icon {
        id: tr
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: root.trailing
        font.pixelSize: 14
        color: Theme.fgDim
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
