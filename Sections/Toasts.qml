import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Services
import qs.Components
import qs.Utils

// Notification popups: glass cards stacked in the top-right corner of the
// focused screen, sliding in from the edge. Same content as the dashboard list;
// click runs the default action and dismisses, they expire on their own otherwise.
PanelWindow {
    id: win
    readonly property int margin: 12
    readonly property var popups: Notifs.shownPopups

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    visible: popups.length > 0
    color: "transparent"
    WlrLayershell.namespace: "gshell-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + margin; right: margin }
    implicitWidth: 360
    implicitHeight: Math.max(1, stack.height)
    mask: Region { item: stack }

    Backdrop {
        id: wall // not `backdrop`: GlassSurface's own property would shadow it in the delegate
        screen: win.screen
        active: win.visible
        snapshot: true
    }

    Column {
        id: stack
        width: parent.width
        spacing: Theme.gap
        // the rest close the gap left by a removed popup
        move: Transition { NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic } }
        Repeater {
            // ScriptModel keeps existing delegates (and their timers) when the list changes
            model: ScriptModel { values: win.popups.slice(0, 4) }
            Item {
                id: toast
                required property var modelData
                width: stack.width
                height: col.height + Theme.padTile * 2 + 8
                property bool shown: false
                property var then: null
                Component.onCompleted: shown = true
                // slide out first, then hide the popup (and run `fn`, e.g. dismiss)
                function close(fn) {
                    if (!shown) return;
                    then = fn;
                    shown = false;
                    leave.start();
                }
                Timer {
                    running: toast.shown && !hover.hovered
                    interval: toast.modelData.expireTimeout > 0 ? toast.modelData.expireTimeout : 5000
                    onTriggered: toast.close(null)
                }
                Timer {
                    id: leave
                    interval: 320
                    // grab both first: either call can remove (destroy) this delegate
                    onTriggered: { const f = toast.then, n = toast.modelData; f?.(); Notifs.expire(n) }
                }

                GlassSurface {
                    id: glass
                    backdrop: wall.texture
                    offset: Qt.point((win.screen?.width ?? 0) - win.width - win.margin, Theme.barHeight + win.margin)
                    width: parent.width; height: parent.height
                    // hidden: just past the screen's right edge
                    x: toast.shown ? 0 : width + win.margin
                    moving: x
                    radius: Theme.radiusTile
                    bevel: 14
                    tint: Qt.rgba(0, 0, 0, 0.06) // barely there: whites stay white
                    vibrancy: 0.6
                    opacity: toast.shown ? 1 : 0
                    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 260 } }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        // left: default action + dismiss; right: just hide the popup (stays in the dashboard)
                        onClicked: m => m.button === Qt.RightButton ? toast.close(null) : col.act(null)
                    }
                    HoverHandler { id: hover }
                    NotifContent {
                        id: col
                        x: Theme.padTile + 4; y: Theme.padTile + 4
                        width: parent.width - x * 2
                        notif: toast.modelData
                        onAct: a => toast.close(() => {
                            (a ?? notif.actions.find(a => a.identifier === "default"))?.invoke();
                            notif.dismiss();
                        })
                    }
                }
            }
        }
    }
}
