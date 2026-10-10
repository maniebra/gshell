import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Services

// What lies under the shell on `screen`: wallpaper plus captures of the
// windows on the active workspace. Pass `texture` to GlassSurface.
// `snapshot` instead grabs the whole output once each time `active` turns on:
// composited exactly as seen (per-window captures of clients rendering at a
// different scale come out magnified), but static while the panel is open.
Item {
    id: root
    required property var screen
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property alias texture: tex
    property bool active: true
    property bool snapshot: false
    onActiveChanged: if (active && snapshot) shot.captureFrame()
    // ponytail: mirrors decoration in ~/.config/hypr/hyprland.lua by hand; read via hyprctl getoption if it drifts
    readonly property int rounding: 16
    readonly property real roundingPower: 5
    readonly property int border: 1
    readonly property color activeBorder: "#ee8c8c8c"
    readonly property color inactiveBorder: "#aa595959"

    ShaderEffectSource {
        id: tex
        width: root.screen.width
        height: root.screen.height
        visible: false
        live: true
        hideSource: true
        mipmap: true // glass blurs by sampling coarser mip levels
        smooth: true
        // physical px, else fractional scales (1.25) sample a low-res, jaggy copy
        textureSize: Qt.size(width * root.screen.devicePixelRatio, height * root.screen.devicePixelRatio)
        sourceItem: content
    }

    Item {
        id: content
        width: root.screen.width
        height: root.screen.height

        ScreencopyView {
            id: shot
            anchors.fill: parent
            visible: root.snapshot
            captureSource: root.snapshot ? root.screen : null
            live: false
        }

        Image {
            anchors.fill: parent
            visible: !root.snapshot
            source: Wallpaper.pathFor(root.screen.name)
            fillMode: Image.PreserveAspectCrop // hyprpaper "cover"
            sourceSize: Qt.size(width, height)
            asynchronous: true
        }

        Repeater {
            // stable model: delegates (and their captures) persist, only move
            model: root.snapshot ? [] : Hyprland.toplevels

            // captures carry no compositor decoration; redraw border + rounding
            // in one shader pass straight off the capture texture
            ShaderEffect {
                id: win
                required property var modelData
                readonly property var ipc: modelData.lastIpcObject
                readonly property bool bare: !!ipc?.fullscreen // f[1] rule drops border + rounding
                readonly property int b: bare ? 0 : root.border
                visible: modelData.workspace?.id === root.monitor?.activeWorkspace?.id && !!ipc?.at
                // ponytail: z-order approximated as tiled < floating, recent focus on top
                z: (ipc?.floating ? 1000 : 0) - (ipc?.focusHistoryID ?? 0)
                x: (ipc?.at?.[0] ?? 0) - root.screen.x - b
                y: (ipc?.at?.[1] ?? 0) - root.screen.y - b
                width: (ipc?.size?.[0] ?? 0) + 2 * b
                height: (ipc?.size?.[1] ?? 0) + 2 * b
                fragmentShader: Qt.resolvedUrl("../Shaders/winclip.frag.qsb")
                property size itemSize: Qt.size(width, height)
                property real radius: bare ? 0 : root.rounding + b // Hyprland draws the border outside the window
                property real border: b
                property real power: root.roundingPower
                property color borderColor: ipc?.focusHistoryID === 0 ? root.activeBorder : root.inactiveBorder
                property var src: ShaderEffectSource {
                    hideSource: true
                    smooth: true
                    // physical px so text survives at fractional scales
                    textureSize: Qt.size(cap.width * root.screen.devicePixelRatio, cap.height * root.screen.devicePixelRatio)
                    sourceItem: ScreencopyView {
                        id: cap
                        parent: win
                        width: win.width - 2 * win.b; height: win.height - 2 * win.b
                        captureSource: root.active && win.visible ? win.modelData.wayland : null
                        live: true
                    }
                }
            }
        }
    }

    // Window geometry lives in lastIpcObject, which only updates on refresh,
    // and Hyprland sends no events mid-drag, so poll at frame rate.
    // ponytail: 60Hz IPC poll, gate on a drag/floating window if CPU shows up
    Timer {
        interval: 16
        running: root.active && !root.snapshot && (root.monitor?.focused ?? false) // drags happen on the focused monitor
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }
}
