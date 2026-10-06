pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property color bg: "#1e1e2e"
    readonly property color fg: "#ffffff"
    readonly property color fgDim: Qt.rgba(1, 1, 1, 0.6)
    readonly property color accent: "#0a84ff"
    readonly property color fill: Qt.rgba(1, 1, 1, 0.16)
    readonly property int barHeight: 34
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
