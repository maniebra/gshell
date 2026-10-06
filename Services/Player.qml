pragma Singleton

import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    function score(p) {
        return ((p.trackArtUrl ?? "") !== "" ? 8 : 0)
            + ((p.trackTitle ?? "") !== "" ? 4 : 0)
            + (p.playbackState === MprisPlaybackState.Playing ? 2 : 0)
            + (p.canControl ? 1 : 0);
    }

    property string pinned: ""

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
