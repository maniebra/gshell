import QtQuick

// Refracts `backdrop` (a Backdrop covering the whole screen) behind itself.
Item {
    id: root
    required property var backdrop
    property point offset: Qt.point(0, 0) // window position on screen
    // bind to an animated value that scales/moves an ancestor (e.g. an open
    // progress), so the screen position is re-mapped instead of going stale
    property real moving: 0
    property real radius: height / 2
    property real bevel: Math.min(radius, 16)
    property real strength: bevel * 3 // px the rim bends rays by (x ~1.1 at the very edge)
    property real ior: 1.5
    property real dispersion: 0.12
    property real blur: 1.5
    property real skew: 3.5
    property real noise: 0.015
    property real vibrancy: 0.35
    property color tint: Qt.rgba(1, 1, 1, 0.04)
    // liquid shape: the slab inside the item, plus a capsule melted into it
    property rect body: Qt.rect(0, 0, width, height)
    property rect neck: Qt.rect(0, 0, 0, 0)
    property real goo: 0

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../Shaders/glass.frag.qsb")
        property var wall: root.backdrop
        property size itemSize: Qt.size(width, height)
        property point itemPos: { root.x; root.y; root.moving; const m = root.mapToItem(null, 0, 0); return Qt.point(m.x + root.offset.x, m.y + root.offset.y) }
        // on-screen size, so sampling tracks scale animations
        property size itemSpan: { root.moving; const a = root.mapToItem(null, 0, 0), b = root.mapToItem(null, width, height); return Qt.size(b.x - a.x, b.y - a.y) }
        property size screenSize: Qt.size(root.backdrop.width, root.backdrop.height)
        property real radius: root.radius
        property real bevel: root.bevel
        property real strength: root.strength
        property real ior: root.ior
        property real dispersion: root.dispersion
        property real blur: root.blur
        property real skew: root.skew
        property real noise: root.noise
        property real vibrancy: root.vibrancy
        property color tint: root.tint
        property rect body: root.body
        property rect neck: root.neck
        property real goo: root.goo
    }
}
