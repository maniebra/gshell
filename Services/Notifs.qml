pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Notification daemon; keeps everything until dismissed so the dashboard can list it.
Singleton {
    readonly property var list: server.trackedNotifications.values
    function clear() { for (const n of [...list]) n.dismiss() }
    // fresh ones shown as toasts until they time out; dismissed ones drop out of `list`
    property var popups: []
    readonly property var shownPopups: popups.filter(n => list.includes(n))
    function expire(n) { popups = popups.filter(p => p !== n) }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => { n.tracked = true; popups = [n, ...popups] }
    }
}
