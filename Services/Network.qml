pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: root

    property string name: ""
    property string type: ""
    property int strength: 0
    property bool wifiEnabled: true

    property var vpns: []
    readonly property var activeVpn: vpns.find(v => v.active) ?? null
    readonly property bool vpnUp: activeVpn !== null

    property var wired: []

    readonly property bool connected: name !== ""

    readonly property string icon: {
        if (!connected)
            return type === "wifi" || wifiEnabled ? "" : "";
        if (type === "ethernet")
            return "";
        if (strength >= 75)
            return "";
        if (strength >= 50)
            return "";
        if (strength >= 25)
            return "";
        return "";
    }

    readonly property string label: connected ? name : "Offline"

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: list.running = true
    }

    Process {
        id: probe
        command: ["sh", "-c", `
            command -v nmcli >/dev/null 2>&1 || exit 0
            printf 'radio %s\\n' "$(nmcli -t radio wifi 2>/dev/null)"
            nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null |
                awk -F: '$1=="yes"{printf "wifi %s %s\\n", $3, $2; exit}'
            nmcli -t -f TYPE,STATE,CONNECTION dev status 2>/dev/null |
                awk -F: '$1=="ethernet" && $2=="connected"{printf "eth %s\\n", $3; exit}'
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                let type = "";
                let strength = 0;

                for (const line of text.trim().split("\n")) {
                    const parts = line.trim().split(" ");
                    if (parts[0] === "radio") {
                        root.wifiEnabled = parts[1] === "enabled";
                    } else if (parts[0] === "wifi") {
                        strength = parseInt(parts[1]) || 0;
                        name = parts.slice(2).join(" ");
                        type = "wifi";
                    } else if (parts[0] === "eth" && type === "") {
                        name = parts.slice(1).join(" ");
                        type = "ethernet";
                    }
                }

                root.name = name;
                root.type = type;
                root.strength = strength;
            }
        }
    }

    property var networks: []
    property bool scanning: false
    property string error: ""

    function scan() {
        error = "";
        scanning = true;
        list.running = true;
    }

    function connect(ssid, password) {
        error = "";
        scanning = true;
        connector.command = ["sh", "-c", `
            if nmcli -t -f NAME con show | grep -qxF ${shellQuote(ssid)}; then
                nmcli con up id ${shellQuote(ssid)}
            else
                nmcli dev wifi connect ${shellQuote(ssid)}` +
                (password ? ` password ${shellQuote(password)}` : "") + `
            fi
        `];
        connector.running = true;
    }

    function forget(ssid) {
        Quickshell.execDetached(["nmcli", "con", "delete", "id", ssid]);
        refresh.restart();
    }

    function shellQuote(s) {
        return `'${String(s).replace(/'/g, `'\\''`)}'`;
    }

    Process {
        id: list
        command: ["sh", "-c", `
            command -v nmcli >/dev/null 2>&1 || exit 0
            nmcli -t -f NAME con show 2>/dev/null | sed 's/^/known:/'
            nmcli -t -f NAME,TYPE,STATE con show 2>/dev/null | sed 's/^/con:/'
            nmcli --escape no -t -f ACTIVE,SIGNAL,SECURITY,SSID dev wifi list 2>/dev/null |
                sed 's/^/ap:/'
            nmcli -t -f TYPE,STATE dev status 2>/dev/null |
                awk -F: '$1=="ethernet"{print "eth:" $2}'
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const known = {};
                const seen = {};
                const aps = [];
                const vpns = [];
                const wired = [];
                let cable = false;

                for (const line of text.split("\n")) {
                    if (line.startsWith("known:")) {
                        known[line.slice(6)] = true;
                        continue;
                    }
                    if (line.startsWith("eth:")) {
                        // "unavailable" = no carrier; anything else means a cable is in
                        if (line !== "eth:unavailable" && line !== "eth:unmanaged")
                            cable = true;
                        continue;
                    }
                    if (line.startsWith("con:")) {
                        const f = line.slice(4).split(":");
                        const state = f.pop();
                        const type = f.pop();
                        const name = f.join(":");
                        if (name !== "" && (type === "vpn" || type === "wireguard" || type === "tun"))
                            vpns.push({
                                name: name,
                                type: type,
                                active: state === "activated"
                            });
                        else if (name !== "" && type === "802-3-ethernet")
                            wired.push({
                                name: name,
                                type: "lan",
                                active: state === "activated"
                            });
                        continue;
                    }
                    if (!line.startsWith("ap:"))
                        continue;

                    const parts = line.slice(3).split(":");
                    const ssid = parts.slice(3).join(":");
                    if (ssid === "" || seen[ssid])
                        continue;
                    seen[ssid] = true;

                    aps.push({
                        ssid: ssid,
                        signal: parseInt(parts[1]) || 0,
                        secured: parts[2] !== "",
                        active: parts[0] === "yes"
                    });
                }

                root.vpns = vpns.sort((a, b) =>
                    (b.active ? 1 : 0) - (a.active ? 1 : 0) || a.name.localeCompare(b.name));

                root.wired = wired.map(w => Object.assign(w, { cable: cable }));

                root.networks = aps
                    .map(ap => Object.assign(ap, { known: known[ap.ssid] === true }))
                    .sort((a, b) => b.signal - a.signal);
                root.scanning = false;
            }
        }
    }

    Process {
        id: connector

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim().split("\n").pop() ?? "";
                root.error = msg.replace(/^Error:\s*/, "");
            }
        }

        onExited: code => {
            root.scanning = false;
            if (code === 0)
                root.error = "";
            probe.running = true;
            list.running = true;
        }
    }

    function vpnToggle(name) {
        const entry = root.vpns.concat(root.wired).find(v => v.name === name);
        if (!entry)
            return;
        connector.command = ["nmcli", "con", entry.active ? "down" : "up", "id", name];
        connector.running = true;
        root.scanning = true;
    }

    function toggleWifi() {
        Quickshell.execDetached([
            "nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"
        ]);
        wifiEnabled = !wifiEnabled;
        refresh.restart();
    }

    function openEditor() {
        Quickshell.execDetached([
            "sh", "-c",
            "command -v nm-connection-editor >/dev/null && exec nm-connection-editor || exec kitty -e nmtui"
        ]);
    }

    Timer {
        id: refresh
        interval: 1200
        onTriggered: probe.running = true
    }
}
