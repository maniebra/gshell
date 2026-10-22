import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Services
import qs.Utils

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
    property real captureHeight: screen.height
    property real textureScale: 1
    // whose windows to draw; another id renders that workspace (desktop peek)
    property int workspace: monitor?.activeWorkspace?.id ?? -1
    property bool snapshot: false
    // Warm window captures in small batches so a new glass surface opens with
    // its wallpaper immediately instead of sampling every window in one frame.
    property int readyCaptures: 0
    // open special workspace (win+s scratchpad) on this monitor, 0 if none
    readonly property int special: workspace === (monitor?.activeWorkspace?.id ?? -1) ? (monitor?.lastIpcObject?.specialWorkspace?.id ?? 0) : 0
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "activespecial") Hyprland.refreshMonitors() }
    }
    onActiveChanged: {
        readyCaptures = 0
        if (active && snapshot) shot.captureFrame()
    }
    // ponytail: mirrors decoration in ~/.config/hypr/hyprland.lua by hand; read via hyprctl getoption if it drifts
    readonly property int rounding: 16
    readonly property real roundingPower: 5
    readonly property int border: 1
    readonly property color activeBorder: "#ee8c8c8c"
    readonly property color inactiveBorder: "#aa595959"

    ShaderEffectSource {
        id: tex
        width: root.screen.width
        height: root.captureHeight
        visible: false
        live: root.active
        hideSource: true
        mipmap: !ShellState.lowGpu // glass blurs by sampling coarser mip levels
        smooth: true
        sourceRect: Qt.rect(0, 0, width, height)
        // native resolution for glass; preview textures match their displayed size
        textureSize: Qt.size(width * root.screen.devicePixelRatio * root.textureScale, height * root.screen.devicePixelRatio * root.textureScale)
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
            id: windows
            // stable model: delegates (and their captures) persist, only move
            model: root.snapshot || ShellState.lowGpu ? [] : Hyprland.toplevels

            // captures carry no compositor decoration; redraw border + rounding
            // in one shader pass straight off the capture texture
            ShaderEffect {
                id: win
                required property int index
                required property var modelData
                readonly property int captureIndex: index
                readonly property var ipc: modelData.lastIpcObject
                readonly property bool bare: !!ipc?.fullscreen // f[1] rule drops border + rounding
                readonly property int b: bare ? 0 : root.border
                readonly property bool onSpecial: root.special !== 0 && modelData.workspace?.id === root.special
                visible: (modelData.workspace?.id === root.workspace || onSpecial) && !!ipc?.at
                // ponytail: z-order approximated as special > floating > tiled, recent focus on top
                z: (onSpecial ? 2000 : ipc?.floating ? 1000 : 0) - (ipc?.focusHistoryID ?? 0)
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
                    // match the outer texture's scale for preview captures
                    textureSize: Qt.size(cap.width * root.screen.devicePixelRatio * root.textureScale, cap.height * root.screen.devicePixelRatio * root.textureScale)
                    sourceItem: ScreencopyView {
                        id: cap
                        parent: win
                        width: win.width - 2 * win.b; height: win.height - 2 * win.b
                        captureSource: root.active && win.visible && win.captureIndex < root.readyCaptures ? win.modelData.wayland : null
                        live: true
                    }
                }
            }
        }
    }

    Timer {
        interval: 16
        running: root.active && !root.snapshot && root.readyCaptures < windows.count
        repeat: true
        onTriggered: root.readyCaptures += 2
    }

    // Window geometry lives in lastIpcObject, which only updates on refresh,
    // and Hyprland sends no events mid-drag, so poll at frame rate.
    // ponytail: 60Hz IPC poll, gate on a drag/floating window if CPU shows up
    Timer {
        interval: 16
        running: root.active && !root.snapshot && !ShellState.lowGpu && (root.monitor?.focused ?? false) // drags happen on the focused monitor
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }
}
