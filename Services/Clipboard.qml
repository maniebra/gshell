pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history, newest first, persisted. No cliphist needed:
// wl-paste --watch reruns the script on every copy. Entries are
// { text } or { image: path }; images are stored by content hash so
// re-copying one doesn't duplicate it. Password-manager copies are skipped.
Singleton {
    id: root
    property var history: []
    readonly property int max: 50
    readonly property string dir: Quickshell.dataPath("clipboard")

    // copy back, then paste into the window that regains focus once the launcher closes
    function paste(e) {
        const copy = e.image ? 'wl-copy < "$1"' : 'wl-copy -- "$1"';
        Quickshell.execDetached(["sh", "-c", copy + "; sleep 0.15; wtype -M ctrl v -m ctrl", "sh", e.image ?? e.text]);
    }
    function clear() {
        history = [];
        save();
        Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*', "sh", dir]);
    }
    function save() { store.setText(JSON.stringify(history)) }

    function add(e) {
        const same = x => e.image ? x.image === e.image : x.text === e.text;
        const next = [e, ...history.filter(x => !same(x))];
        // drop image files that fall off the end
        for (const x of next.slice(max))
            if (x.image) Quickshell.execDetached(["rm", "-f", x.image]);
        history = next.slice(0, max);
        save();
    }

    Process {
        running: true
        // emits "I<path>\0" or "T<text>\0" per copy
        command: ["wl-paste", "--watch", "sh", "-c", `
            cat >/dev/null
            types=$(wl-paste -l)
            case "$types" in *x-kde-passwordManagerHint*) exit;; esac
            if printf '%s' "$types" | grep -q '^image/'; then
                mkdir -p "$0"
                f="$0/$(wl-paste -t image | md5sum | cut -c1-32).img"
                [ -e "$f" ] || wl-paste -t image > "$f"
                printf 'I%s\\0' "$f"
            elif printf '%s' "$types" | grep -q '^text/\\|STRING'; then
                printf T; wl-paste -n -t text; printf '\\0'
            fi`, root.dir]
        stdout: SplitParser {
            splitMarker: "\0"
            onRead: line => {
                const body = line.slice(1);
                if (line[0] === "I") root.add({ image: body });
                else if (line[0] === "T" && body.trim()) root.add({ text: body });
            }
        }
    }

    FileView {
        id: store
        path: Quickshell.dataPath("clipboard.json")
        // older files stored plain strings
        onLoaded: try { root.history = JSON.parse(text()).map(x => typeof x === "string" ? { text: x } : x) } catch (e) {}
    }
}
