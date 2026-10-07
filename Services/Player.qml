pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    function score(p) {
        return ((p.trackArtUrl ?? "") !== "" ? 8 : 0)
            + ((p.trackTitle ?? "") !== "" ? 4 : 0)
            + (p.playbackState === MprisPlaybackState.Playing ? 2 : 0)
            + (p.canControl ? 1 : 0);
    }

    property string pinned: ""
    // direction of the last track skip, for slide animations: 1 next, -1 previous
    property int dir: 1

    // dominant vivid color of the current cover art; transparent if none.
    // Picks the most saturated of the quantized colors, skipping near-black
    // and near-white ones whose hue is meaningless.
    readonly property color artColor: {
        const cs = quant.colors.filter(c => c.hslLightness > 0.12 && c.hslLightness < 0.92);
        if (cs.length === 0) return "transparent";
        return cs.reduce((a, b) => b.hslSaturation > a.hslSaturation ? b : a);
    }
    ColorQuantizer {
        id: quant
        depth: 3 // 8 colors
        rescaleSize: 64
    }
    // the quantizer only reads local files; remote art (Spotify) is fetched first
    readonly property string artUrl: current?.trackArtUrl ?? ""
    onArtUrlChanged: {
        if (!artUrl.startsWith("http")) { quant.source = artUrl; return; }
        fetch.target = Quickshell.cachePath("cover-" + Qt.md5(artUrl));
        fetch.running = false;
        fetch.running = true;
    }
    Process {
        id: fetch
        property string target
        command: ["curl", "-sfLo", target, "--create-dirs", root.artUrl]
        onExited: code => quant.source = code === 0 ? "file://" + target : ""
    }

    function next() { dir = 1; current?.next() }
    function previous() { dir = -1; current?.previous() }

    function pin(name) {
        root.pinned = name;
    }

    readonly property var current: {
        const all = Mpris.players.values.slice();
        if (all.length === 0)
            return null;

        if (root.pinned !== "") {
            const hit = all.find(p => p.dbusName === root.pinned);
            if (hit)
                return hit;
        }

        all.sort((a, b) => {
            const d = root.score(b) - root.score(a);
            return d !== 0 ? d : (a.dbusName < b.dbusName ? -1 : 1);
        });

        return all[0];
    }

    readonly property var sources: {
        const best = {};
        for (const p of Mpris.players.values) {
            const key = p.identity ?? p.dbusName;
            if (!best[key] || root.score(p) > root.score(best[key]))
                best[key] = p;
        }
        return Object.keys(best).sort().map(k => best[k]);
    }

    readonly property bool playing:
        Mpris.players.values.some(p => p.playbackState === MprisPlaybackState.Playing)
}
