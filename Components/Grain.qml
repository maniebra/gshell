import QtQuick

// Film grain overlay for matte surfaces; fill the surface and match its radius.
ShaderEffect {
    property real radius: 0
    property real amount: 0.035
    property size itemSize: Qt.size(width, height)
    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl("../Shaders/grain.frag.qsb")
}
