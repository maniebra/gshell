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
    // Picked once per cover and cached by art URL (cover-colors.json), so a
    // known cover needs neither a download nor a quantize pass.
    readonly property string artUrl: current?.trackArtUrl ?? ""
    readonly property color artColor: artUrl !== "" && colorCache.colors[artUrl] ? colorCache.colors[artUrl] : "transparent"

    FileView {
        path: Quickshell.cachePath("cover-colors.json")
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoadFailed: e => { if (e === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: colorCache
            property var colors: ({}) // art URL -> "#rrggbb"
        }
    }

    // most saturated quantized color, skipping near-black/white whose hue is noise
    function pick(colors) {
        const cs = colors.filter(c => c.hslLightness > 0.12 && c.hslLightness < 0.92);
        return cs.length ? cs.reduce((a, b) => b.hslSaturation > a.hslSaturation ? b : a) : null;
    }

    ColorQuantizer {
        id: quant
        property string url // art URL the current source belongs to
        depth: 3 // 8 colors
        rescaleSize: 64
        onColorsChanged: {
            if (!url || colors.length === 0) return;
            const c = root.pick(colors);
            // ponytail: cache grows one entry per cover, prune if it ever gets big
            colorCache.colors = Object.assign({}, colorCache.colors, { [url]: c ? c.toString() : "" });
            url = "";
        }
    }
    function quantize(url, src) { quant.url = url; quant.source = src }

    // the quantizer only reads local files; remote art (Spotify) is fetched
    // first, reusing an already-downloaded cover
    onArtUrlChanged: {
        if (artUrl === "" || artUrl in colorCache.colors) return;
        if (!artUrl.startsWith("http")) { quantize(artUrl, artUrl); return; }
        fetch.url = artUrl;
        fetch.target = Quickshell.cachePath("cover-" + Qt.md5(artUrl));
        fetch.running = false;
        fetch.running = true;
    }
    Process {
        id: fetch
        property string url
        property string target
        command: ["sh", "-c", '[ -s "$1" ] || curl -sfLo "$1" --create-dirs "$2"', "sh", target, url]
        onExited: code => { if (code === 0) root.quantize(url, "file://" + target) }
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
