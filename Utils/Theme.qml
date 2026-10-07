pragma Singleton

import Quickshell
import QtQuick
import qs.Services

Singleton {
    readonly property color bg: "#1e1e2e"
    readonly property color fg: "#ffffff"
    readonly property color fgDim: Qt.rgba(1, 1, 1, 0.6)
    // user-picked (Dashboard > Appearance); optionally takes hue and saturation
    // from the cover art, keeping the picked color's lightness
    readonly property color accentBase: ShellState.accent
    property color accent: ShellState.accentFromArt ? fromArt(accentBase) : accentBase
    Behavior on accent { ColorAnimation { duration: 500 } }
    // tinted app icons, same option
    property color iconTint: ShellState.iconTintFromArt ? fromArt(ShellState.iconTint) : ShellState.iconTint
    Behavior on iconTint { ColorAnimation { duration: 500 } }

    // `base` with the cover art's hue and saturation; unchanged without art.
    // Lightness comes from `base` but is kept mid-range: at white or black
    // (l = 1 or 0) hue and saturation would have no visible effect.
    function fromArt(base) {
        const a = Player.artColor;
        const l = Math.max(0.45, Math.min(0.75, Qt.color(base).hslLightness));
        return a.a > 0 ? Qt.hsla(a.hslHue, a.hslSaturation, l, 1) : base;
    }
    readonly property color fill: Qt.rgba(1, 1, 1, 0.16)
    // matte tiles inside glass panels: mostly opaque grey, grain on top
    readonly property color matte: Qt.rgba(0.2, 0.2, 0.215, 0.85)
    readonly property color matteBorder: Qt.rgba(1, 1, 1, 0.1)
    readonly property int barHeight: 28
    readonly property int gap: 6
    // concentric corners: outer radius = inner radius + padding
    readonly property int radiusControl: 8
    readonly property int padTile: 8
    readonly property int radiusTile: radiusControl + padTile
    readonly property int padPanel: 8
    readonly property int radiusPanel: radiusTile + padPanel
    readonly property string font: "SF Pro Text"
    readonly property string iconFont: "SF Pro Text"
}
