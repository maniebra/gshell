pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Output management through Hyprland's Lua API (hyprctl eval hl.monitor).
// Runtime only: a config reload restores the rules in hyprland.lua.
Singleton {
    id: root
    // raw objects from `hyprctl monitors all -j`
    property var all: []
    readonly property var internal: all.find(m => m.name.startsWith("eDP")) ?? null
    readonly property var externals: all.filter(m => !m.name.startsWith("eDP"))
    readonly property int enabledCount: all.filter(m => !m.disabled).length

    function refresh() { query.running = true }

    // "left" | "right" | "mirror" | "off" relative to the laptop panel
    function layoutOf(m) {
        if (m.disabled) return "off";
        if (m.mirrorOf && m.mirrorOf !== "none") return "mirror";
        return m.x < (internal?.x ?? 0) ? "left" : "right";
    }

    function modeOf(m) { return `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}Hz` }

    function apply(m, spec) {
        const cur = {
            output: m.name,
            mode: m.disabled ? "preferred" : modeOf(m).replace("Hz", ""),
            position: "auto",
            scale: String(m.scale),
            // hyprland merges rule fields, so stale mirror/disabled must be cleared explicitly
            mirror: "",
            disabled: false
        };
        const s = Object.assign(cur, spec);
        const lua = "hl.monitor({" + Object.entries(s).map(([k, v]) =>
            k + " = " + (typeof v === "boolean" ? v : JSON.stringify(String(v)))).join(", ") + "})";
        Quickshell.execDetached(["hyprctl", "eval", lua]);
        settle.restart();
    }

    function setLayout(m, l) {
        // never switch off the last lit screen
        if (l === "off" && !m.disabled && enabledCount <= 1) return;
        if (l === "off") apply(m, { disabled: true });
        else if (l === "mirror") apply(m, { mirror: internal?.name ?? "", position: "auto" });
        else apply(m, { position: l === "left" ? "auto-left" : "auto-right" });
    }
    function setMode(m, mode) { apply(m, { mode: mode.replace("Hz", "") }) }
    function setScale(m, s) { apply(m, { scale: s }) }

    // hyprland applies asynchronously; re-read once it settles
    Timer { id: settle; interval: 400; onTriggered: root.refresh() }

    Process {
        id: query
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector { onStreamFinished: try { root.all = JSON.parse(text) } catch (e) {} }
    }

    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name.startsWith("monitor")) root.refresh() }
    }

    Component.onCompleted: refresh()
}
