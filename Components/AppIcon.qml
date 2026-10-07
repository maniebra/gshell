import QtQuick
import Quickshell
import qs.Utils

// Themed app icon for a window class / desktop id, styled per `style`
// (ShellState.iconStyle). `tint` colors the foreground in "tinted" style.
// Falls back to a tile with the app's initial.
Item {
    id: root
    property string appId
    property string style: ShellState.iconStyle
    property color tint: Theme.iconTint
    readonly property url source: Quickshell.iconPath(DesktopEntries.heuristicLookup(appId)?.icon || appId.toLowerCase(), true)
    readonly property int mode: ["default", "dark", "clear", "tinted"].indexOf(style)
    implicitWidth: 16 // 16 and 32 land on whole pixels at 1.25x scale
    implicitHeight: 16

    readonly property real dpr: Screen.devicePixelRatio

    // default style: rasterize the SVG at exactly the on-screen pixel size
    // (fractional scaling included), so nothing gets resampled
    Image {
        id: img
        anchors.fill: parent
        visible: root.mode === 0
        sourceSize: Qt.size(Math.round(width * root.dpr), Math.round(height * root.dpr))
        smooth: true
        source: root.source
    }

    // other styles: the style shader works per pixel, which is noisy at icon
    // size, so run it at 4x and mipmap the result down
    Item {
        id: big
        visible: root.mode > 0 // hidden from view by the capture below
        width: root.width * 4; height: root.height * 4
        readonly property size px: Qt.size(Math.round(width * root.dpr), Math.round(height * root.dpr))
        Image {
            anchors.fill: parent
            sourceSize: big.px
            source: root.mode > 0 ? root.source : ""
            layer.enabled: true
            layer.mipmap: true // the shader reads blurred plate colors from mips
            layer.textureSize: big.px
            layer.effect: ShaderEffect {
                fragmentShader: Qt.resolvedUrl("../Shaders/iconstyle.frag.qsb")
                property real mode: root.mode
                property color tint: root.tint
            }
        }
    }
    ShaderEffectSource {
        anchors.fill: parent
        visible: root.mode > 0
        live: root.mode > 0
        sourceItem: root.mode > 0 ? big : null
        hideSource: true
        textureSize: big.px
        mipmap: true
        smooth: true
    }

    Rectangle {
        visible: img.status !== Image.Ready
        anchors.fill: parent
        radius: height * 0.28
        antialiasing: true
        color: root.mode === 3 ? Qt.rgba(0.11, 0.11, 0.11, 1) : root.mode === 1 ? Qt.rgba(0, 0, 0, 0.5) : Theme.fill
        StyledText {
            anchors.centerIn: parent
            text: root.appId.replace(/^.*\./, "").charAt(0).toUpperCase()
            font.pixelSize: parent.height * 0.6
            font.weight: Font.Bold
            color: root.mode === 3 ? root.tint : Theme.fg
        }
    }
}
