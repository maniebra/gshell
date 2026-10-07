pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Notification daemon; keeps everything until dismissed so the dashboard can list it.
Singleton {
    readonly property var list: server.trackedNotifications.values
    function clear() { for (const n of [...list]) n.dismiss() }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => n.tracked = true
    }
}
