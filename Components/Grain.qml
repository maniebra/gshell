import QtQuick
import qs.Utils

// Film grain overlay for matte surfaces; fill the surface and match its radius.
ShaderEffect {
    property real radius: 0
    property real amount: 0.035
    property size itemSize: Qt.size(width, height)
    anchors.fill: parent
    visible: !ShellState.lowGpu
    fragmentShader: Qt.resolvedUrl("../Shaders/grain.frag.qsb")
}
