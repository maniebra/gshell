import QtQuick
import qs.Services
import qs.Utils

// iOS-style battery: rounded pill, fill level, percentage inside, nub on the right
Row {
    id: root
    spacing: 1.5

    readonly property color tint: Battery.low ? "#ff453a" : Theme.fg

    Rectangle {
        id: body
        width: 23; height: 11
        radius: height / 2.6
        color: Qt.rgba(1, 1, 1, 0.3)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * Battery.level
            radius: parent.radius
            color: root.tint
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 250 } }
        }

        Text {
            id: bolt
            visible: Battery.charging
            text: Icons.charging
            font.family: Theme.iconFont
            font.pixelSize: 7
            color: Battery.level > 0.5 ? "black" : Theme.fg
            anchors { left: parent.left; leftMargin: 1.5; verticalCenter: parent.verticalCenter; verticalCenterOffset: 0.5 }
        }
        Text {
            id: pct
            text: Battery.percent
            font.family: Theme.font
            font.pixelSize: Battery.percent >= 100 ? (Battery.charging ? 7 : 8.5) : 9.5
            font.weight: Font.Bold
            color: Battery.level > 0.5 ? "black" : Theme.fg
            // when charging, center in the space right of the bolt
            anchors { centerIn: parent; verticalCenterOffset: 0.5; horizontalCenterOffset: Battery.charging ? (bolt.x + bolt.width) / 2 : 0 }
        }
    }

    Rectangle {
        width: 1.5; height: 4.5
        radius: 1
        color: Battery.level >= 1 ? root.tint : Qt.rgba(1, 1, 1, 0.3)
        anchors.verticalCenter: parent.verticalCenter
    }
}
