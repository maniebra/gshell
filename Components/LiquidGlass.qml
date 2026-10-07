import QtQuick
import qs.Utils

// Panel glass that grows down out of the bar. Fill the panel window, which
// must start at the bar's bottom edge (not over it: a surface mapped under the
// pointer on the bar clears the focus grab).
GlassSurface {
    id: root
    property real progress   // 0 closed .. 1 open (spring may overshoot)
    property real lift       // window y where the open panel starts
    property real panelH     // open panel height
    property real originX: 0.5 // where along the width the drop hangs, 0..1
    readonly property real p: Math.max(0, Math.min(1, progress))

    anchors.fill: parent
    opacity: Math.min(1, p * 5)
    radius: Theme.radiusPanel
    moving: progress
    body: {
        const w = width * (0.35 + 0.65 * p), h = panelH * (0.15 + 0.85 * p);
        return Qt.rect((width - w) * originX, lift * p, w, h);
    }
}
