import QtQuick
import QtQuick.Effects
import qs.Utils

// Image clipped to rounded corners (Rectangle clip only clips to the bounds).
Rectangle {
    id: root
    property alias source: img.source
    // decode size; fixed so animating the size doesn't reload the image
    property int resolution: 192
    color: Theme.fill
    Image {
        id: img
        anchors.fill: parent
        sourceSize: Qt.size(root.resolution, root.resolution)
        mipmap: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: status === Image.Ready
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    Rectangle { id: mask; anchors.fill: parent; radius: root.radius; visible: false; layer.enabled: true; antialiasing: true }
}
