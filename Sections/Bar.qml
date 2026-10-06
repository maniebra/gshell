import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Services
import qs.Components
import qs.Utils

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.barHeight + Theme.gap * 2
        color: "transparent"
        WlrLayershell.namespace: "gshell-bar"

        Backdrop {
            id: backdrop
            screen: win.modelData
        }

        GlassSurface {
            backdrop: backdrop.texture
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.gap }
            height: Theme.barHeight
            // melt into a panel's liquid neck, so no rim lighting where they join
            readonly property var drip: ShellState.drip
            // only the cap's top few px reach into the bar, so the bar keeps its shape
            neck: drip.screen === win.screen.name && drip.w > 1
                ? Qt.rect(drip.x - x, height - 4, drip.w, drip.w * 2) : Qt.rect(0, 0, 0, 0)
            goo: 16
            radius: Theme.radiusControl + 4

            StyledText {
                anchors.centerIn: parent
                text: Time.time
                MouseArea {
                    anchors { fill: parent; margins: -8 }
                    onClicked: ShellState.dashboard = !ShellState.dashboard
                }
            }

            // status cluster, opens the control center
            Row {
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 12
                Icon { anchors.verticalCenter: parent.verticalCenter; text: Network.wifiEnabled || Network.type === "ethernet" ? (Network.type === "ethernet" ? Icons.lan : Icons.wifi) : Icons.wifiOff; font.pixelSize: 15 }
                Icon { anchors.verticalCenter: parent.verticalCenter; text: Audio.muted ? Icons.volOff : Icons.vol; font.pixelSize: 15 }
                Icon { visible: Battery.available; text: Battery.charging ? Icons.charging : Icons.battery; font.pixelSize: 15 }
                StyledText { anchors.verticalCenter: parent.verticalCenter; visible: Battery.available; text: Battery.percent + "%"; font.pixelSize: 12 }
            }
            // click toggles; a short downward swipe opens. Hyprland stops sending
            // motion once the pointer leaves the bar, so the swipe commits as soon
            // as it crosses a small threshold instead of tracking the full pull.
            MouseArea {
                property real startY
                property bool swiped
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 320
                onPressed: m => { startY = m.y; swiped = false }
                onPositionChanged: m => {
                    if (swiped || m.y - startY < 10) return;
                    swiped = true;
                    ShellState.controlCenter = true;
                }
                onReleased: if (!swiped) ShellState.controlCenter = !ShellState.controlCenter
            }
        }
    }
}
