import QtQuick
import qs.Utils

// Body of a notification card (dashboard list and popups): app icon and name,
// summary, body, image thumbnail, and buttons for the non-default actions.
// `act` fires with the action (null for the default) — the owner invokes and dismisses.
Column {
    id: root
    required property var notif
    signal act(var action)
    spacing: 6

    Row {
        width: parent.width
        spacing: 10
        AppIcon {
            id: icon
            width: 32; height: 32
            appId: root.notif.desktopEntry || root.notif.appName
        }
        Column {
            width: parent.width - icon.width - (thumb.visible ? thumb.width + 10 : 0) - 10
            spacing: 2
            StyledText { text: root.notif.appName; font.pixelSize: 11; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; color: Qt.rgba(1, 1, 1, 0.75) }
            StyledText { width: parent.width; text: root.notif.summary; font.weight: Font.DemiBold; elide: Text.ElideRight }
            StyledText { width: parent.width; text: root.notif.body; color: Theme.fgDim; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; visible: text !== "" }
        }
        RoundedImage {
            id: thumb
            width: 48; height: 48
            radius: Theme.radiusControl
            resolution: 96
            source: root.notif.image
            visible: root.notif.image !== ""
        }
    }

    Row {
        readonly property var actions: root.notif.actions.filter(a => a.identifier !== "default")
        width: parent.width
        spacing: Theme.gap
        visible: actions.length > 0
        Repeater {
            model: parent.actions
            Rectangle {
                required property var modelData
                width: (parent.width - Theme.gap * (parent.actions.length - 1)) / parent.actions.length
                height: 28
                radius: Theme.radiusControl
                color: ma.pressed ? Theme.fill : Qt.rgba(1, 1, 1, 0.1)
                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.act(parent.modelData) }
            }
        }
    }
}
