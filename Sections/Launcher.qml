import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.Components
import qs.Services
import qs.Utils

// Spotlight-style app search, centered upper third of the focused monitor.
// ":" prefix searches emoji (grid), ">" searches clipboard history.
PanelWindow {
    id: win
    readonly property int pad: Theme.padPanel
    readonly property int rowH: 44
    readonly property string query: field.text.trim()
    readonly property string mode: query.startsWith(":") ? "emoji" : query.startsWith(">") ? "clip" : ""
    readonly property string term: (mode ? query.slice(1) : query).trim().toLowerCase()
    readonly property int cols: 12
    property var emojis: []
    // launch counts per app id, persisted so frequent apps rank first
    property var usage: ({})
    property var files: []

    // fuzzy subsequence score: consecutive and word-start hits score higher, -1 = no match
    function fuzzy(q, s) {
        s = s.toLowerCase();
        if (s.startsWith(q)) return 1000 - s.length;
        let score = 0, j = 0, run = 0;
        for (let i = 0; i < s.length && j < q.length; i++) {
            if (s[i] !== q[j]) { run = 0; continue; }
            run++; j++;
            score += run * 2 + (i === 0 || " -_.".includes(s[i - 1]) ? 8 : 0);
        }
        return j === q.length ? score : -1;
    }

    readonly property var apps: {
        const q = term;
        if (!q || mode) return [];
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay)
            .map(a => {
                const kw = Math.max(fuzzy(q, a.genericName ?? ""), ...a.keywords.map(k => fuzzy(q, k))) / 2;
                const s = Math.max(fuzzy(q, a.name), kw);
                return { a, s: s < 0 ? -1 : s + 15 * Math.log2(1 + (usage[a.id] ?? 0)) };
            })
            .filter(x => x.s >= 0)
            .sort((x, y) => y.s - x.s)
            .slice(0, 6)
            .map(x => x.a);
    }

    // calculator: only plain arithmetic reaches the evaluator
    readonly property string calc: {
        if (mode || !/^[\d\s.+\-*\/%()^]+$/.test(query) || !/\d\s*[-+*\/%^]/.test(query)) return "";
        try {
            const v = Function("return (" + query.replace(/\^/g, "**") + ")")();
            return Number.isFinite(v) ? String(+v.toPrecision(12)) : "";
        } catch (e) { return ""; }
    }

    readonly property var emojiHits: {
        if (mode !== "emoji") return [];
        const words = term.split(/\s+/).filter(w => w);
        return emojis.filter(e => words.every(w => e[1].includes(w))).slice(0, cols * 6);
    }
    readonly property var clipHits: mode === "clip"
        ? Clipboard.history.filter(e => (e.text ?? "image").toLowerCase().includes(term)).slice(0, 8) : []

    // flat result list: emoji | clipboard | calculator, apps, files
    readonly property var results: mode === "emoji" ? emojiHits.map(e => ({ kind: "emoji", name: e[0], sub: e[1] }))
        : mode === "clip" ? clipHits.map(e => ({ kind: "clip", entry: e, thumb: e.image ?? "", name: e.image ? "Image" : e.text.replace(/\s+/g, " ").slice(0, 80), sub: "", icon: "edit-paste" }))
            .concat(!term && clipHits.length ? [{ kind: "clipclear", name: "Clear History", sub: "", icon: "edit-clear-all" }] : [])
        : (calc ? [{ kind: "calc", name: calc, sub: "= " + query, icon: "accessories-calculator" }] : [])
        .concat(apps.map(a => ({ kind: "app", app: a, name: a.name, sub: a.genericName ?? "", icon: a.icon })))
        .concat(files.map(f => ({ kind: "file", path: f, name: f.split("/").pop(), sub: f.replace(Quickshell.env("HOME"), "~"), icon: "text-x-generic" })))
    property int current: 0

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    property real progress: ShellState.launcher ? 1 : 0
    Behavior on progress { SpringAnimation { spring: 3.2; damping: 0.3; epsilon: 0.002 } }
    visible: progress > 0.002
    color: "transparent"
    WlrLayershell.namespace: "gshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.launcher ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    margins.top: (screen?.height ?? 0) / 4
    implicitWidth: 640
    implicitHeight: body.height + pad * 2

    onVisibleChanged: if (visible) { field.text = ShellState.launcherPrefix; field.forceActiveFocus() }
    onResultsChanged: current = Math.min(current, Math.max(results.length - 1, 0))
    onQueryChanged: { current = 0; files = []; fileTimer.restart() }

    function launch(r) {
        if (!r) return;
        if (r.kind === "app") {
            r.app.execute();
            usage[r.app.id] = (usage[r.app.id] ?? 0) + 1;
            usageFile.setText(JSON.stringify(usage));
        } else if (r.kind === "emoji") {
            // type it into the window that regains focus once we close
            Quickshell.execDetached(["sh", "-c", 'wl-copy -- "$1"; sleep 0.15; wtype -- "$1"', "sh", r.name]);
        } else if (r.kind === "clip") {
            Clipboard.paste(r.entry);
        } else if (r.kind === "clipclear") {
            Clipboard.clear();
        } else if (r.kind === "calc") {
            Quickshell.execDetached(["wl-copy", r.name]);
        } else {
            Quickshell.execDetached(["xdg-open", r.path]);
        }
        ShellState.launcher = false;
    }

    // switching mode while open (emoji <-> clipboard hotkey)
    Connections {
        target: ShellState
        function onLauncherPrefixChanged() { field.text = ShellState.launcherPrefix }
    }

    FileView {
        path: Quickshell.shellDir + "/Utils/emoji.json"
        onLoaded: win.emojis = JSON.parse(text())
    }

    FileView {
        id: usageFile
        path: Quickshell.dataPath("launcher-usage.json")
        onLoaded: try { win.usage = JSON.parse(text()) } catch (e) {}
    }

    // file search, debounced; ponytail: find over ~ (depth 5), swap for plocate if slow
    Timer {
        id: fileTimer
        interval: 180
        onTriggered: if (win.query.length >= 3 && !win.calc && !win.mode) {
            fileProc.running = false;
            fileProc.command = ["sh", "-c", 'timeout 1 find "$HOME" -maxdepth 5 -not -path "*/.*" -iname "*$1*" 2>/dev/null | head -5', "sh", win.query];
            fileProc.running = true;
        }
    }
    Process {
        id: fileProc
        stdout: StdioCollector { onStreamFinished: win.files = text.split("\n").filter(l => l) }
    }

    HyprlandFocusGrab {
        windows: [win]
        active: ShellState.launcher
        onCleared: ShellState.launcher = false
    }

    Backdrop {
        id: backdrop
        screen: win.screen
        active: win.visible
        snapshot: true
    }
    readonly property point offset: Qt.point(((screen?.width ?? 0) - width) / 2, margins.top)

    Item {
        anchors.fill: parent
        opacity: Math.min(1, win.progress * 1.6)
        scale: 0.92 + 0.08 * win.progress
        transformOrigin: Item.Top

        GlassSurface {
            anchors.fill: parent
            backdrop: backdrop.texture
            offset: win.offset
            moving: win.progress
            radius: Theme.radiusPanel
            bevel: 26
            blur: 1.5
            tint: Qt.rgba(1, 1, 1, 0.03)
        }

        Column {
            id: body
            x: win.pad; y: win.pad
            width: parent.width - win.pad * 2

            Item {
                width: parent.width; height: 48
                Icon {
                    id: glass
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: Icons.search
                    font.pixelSize: 20
                    color: Theme.fgDim
                }
                TextInput {
                    id: field
                    anchors { left: glass.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 22
                    Keys.onEscapePressed: ShellState.launcher = false
                    readonly property int step: win.mode === "emoji" ? win.cols : 1
                    Keys.onDownPressed: win.current = Math.min(win.current + step, win.results.length - 1)
                    Keys.onUpPressed: win.current = Math.max(win.current - step, 0)
                    Keys.onLeftPressed: e => { if (win.mode === "emoji") win.current = Math.max(win.current - 1, 0); else e.accepted = false }
                    Keys.onRightPressed: e => { if (win.mode === "emoji") win.current = Math.min(win.current + 1, win.results.length - 1); else e.accepted = false }
                    Keys.onTabPressed: win.current = (win.current + 1) % Math.max(win.results.length, 1)
                    onAccepted: win.launch(win.results[win.current])
                    StyledText {
                        visible: !parent.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search Apps"
                        color: Theme.fgDim
                        font.pixelSize: 22
                    }
                }
            }

            Rectangle {
                visible: win.results.length > 0
                width: parent.width; height: 1
                color: Theme.fill
            }

            Grid {
                visible: win.mode === "emoji"
                columns: win.cols
                Repeater {
                    model: win.mode === "emoji" ? win.results : []
                    Rectangle {
                        required property var modelData
                        required property int index
                        width: body.width / win.cols; height: width
                        radius: Theme.radiusTile
                        color: index === win.current ? Theme.fill : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 26
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: win.current = index
                            onClicked: win.launch(modelData)
                        }
                    }
                }
            }
            StyledText {
                visible: win.mode === "emoji" && win.results.length > 0
                width: parent.width; height: 28
                leftPadding: 12; verticalAlignment: Text.AlignVCenter
                text: win.results[win.current]?.sub ?? ""
                color: Theme.fgDim
            }

            Repeater {
                model: win.mode === "emoji" ? [] : win.results
                Rectangle {
                    required property var modelData
                    required property int index
                    width: body.width; height: win.rowH
                    radius: Theme.radiusTile
                    color: index === win.current ? Theme.accent : "transparent"

                    AppIcon {
                        id: ic
                        visible: !modelData.thumb
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 28; height: 28
                        appId: modelData.name
                        iconName: modelData.icon || "application-x-executable"
                    }
                    RoundedImage {
                        visible: !!modelData.thumb
                        anchors.fill: ic
                        radius: 6
                        resolution: 64
                        source: modelData.thumb ? "file://" + modelData.thumb : ""
                    }
                    StyledText {
                        anchors { left: ic.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: modelData.name.replace(/&/g, "&amp;").replace(/</g, "&lt;") + (modelData.sub ? "  <font color='#b3ffffff'>— " + modelData.sub.replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</font>" : "")
                        textFormat: Text.StyledText
                        font.pixelSize: 15
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.current = index
                        onClicked: win.launch(modelData)
                    }
                }
            }
        }
    }
}
