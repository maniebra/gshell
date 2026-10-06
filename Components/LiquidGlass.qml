import QtQuick
import qs.Utils

// Panel glass that drips out of the bar: the slab grows down from the bar
// while a liquid neck ties them together, then pinches off like a drop.
// Fill the panel window, which must start at the bar's bottom edge (not over
// it: a surface mapped under the pointer on the bar clears the focus grab).
GlassSurface {
    id: root
    property real progress   // 0 closed .. 1 open (spring may overshoot)
    property real lift       // window y where the open panel starts
    property real panelH     // open panel height
    property real originX: 0.5 // where along the width the drop hangs, 0..1
    property string screenName // so the bar on this screen melts into the neck
    readonly property real p: Math.max(0, Math.min(1, progress)) // overshoot would clip at the window edge
    // neck thins briefly early in the opening, then snaps (real drops part fast)
    readonly property real pinch: 1 - Math.min(1, Math.max(0, (p - 0.15) / 0.3))

    anchors.fill: parent
    opacity: Math.min(1, p * 5)
    radius: Theme.radiusPanel
    moving: progress
    goo: 16
    body: {
        const w = width * (0.35 + 0.65 * p), h = panelH * (0.15 + 0.85 * p);
        return Qt.rect((width - w) * originX, lift * p, w, h);
    }
    neck: {
        const nw = Math.min(body.width * 0.3, 90) * pinch;
        // starts above the window so its top is cut flat against the bar
        return Qt.rect(body.x + (body.width - nw) / 2, -nw, nw, body.y + radius + nw);
    }

    // ponytail: one shared drip, last opening panel wins; per-panel list if both ever animate at once
    onNeckChanged: ShellState.drip = { screen: screenName, x: offset.x + neck.x, w: p < 0.05 ? 0 : neck.width }
}
