import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.Components
import qs.Utils

// Spotlight-style app search, centered upper third of the focused monitor.
PanelWindow {
    id: win
    readonly property int pad: Theme.padPanel
    readonly property int rowH: 44
    readonly property string query: field.text.trim()
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
        const q = query.toLowerCase();
        if (!q) return [];
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
        if (!/^[\d\s.+\-*\/%()^]+$/.test(query) || !/\d\s*[-+*\/%^]/.test(query)) return "";
        try {
            const v = Function("return (" + query.replace(/\^/g, "**") + ")")();
            return Number.isFinite(v) ? String(+v.toPrecision(12)) : "";
        } catch (e) { return ""; }
    }

    // flat result list: calculator, apps, files
    readonly property var results: (calc ? [{ kind: "calc", name: calc, sub: "= " + query, icon: "accessories-calculator" }] : [])
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

    onVisibleChanged: if (visible) { field.text = ""; field.forceActiveFocus() }
    onResultsChanged: current = Math.min(current, Math.max(results.length - 1, 0))
    onQueryChanged: { current = 0; files = []; fileTimer.restart() }

    function launch(r) {
        if (!r) return;
        if (r.kind === "app") {
            r.app.execute();
            usage[r.app.id] = (usage[r.app.id] ?? 0) + 1;
            usageFile.setText(JSON.stringify(usage));
        } else if (r.kind === "calc") {
            Quickshell.execDetached(["wl-copy", r.name]);
        } else {
            Quickshell.execDetached(["xdg-open", r.path]);
        }
        ShellState.launcher = false;
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
        onTriggered: if (win.query.length >= 3 && !win.calc) {
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
            bevel: 18
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
                    Keys.onDownPressed: win.current = Math.min(win.current + 1, win.results.length - 1)
                    Keys.onUpPressed: win.current = Math.max(win.current - 1, 0)
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

            Repeater {
                model: win.results
                Rectangle {
                    required property var modelData
                    required property int index
                    width: body.width; height: win.rowH
                    radius: Theme.radiusTile
                    color: index === win.current ? Theme.accent : "transparent"

                    IconImage {
                        id: ic
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        implicitSize: 28
                        source: Quickshell.iconPath(modelData.icon || "application-x-executable", "application-x-executable")
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
