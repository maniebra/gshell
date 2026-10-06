pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(
        n => !n.isSink && n.audio && !n.isStream)

    function nodeLabel(n) {
        return n?.description || n?.nickname || n?.name || "Unknown";
    }

    function setSink(n) {
        Pipewire.preferredDefaultAudioSink = n;
    }

    function setSource(n) {
        Pipewire.preferredDefaultAudioSource = n;
    }

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? true
    readonly property real micVolume: source?.audio?.volume ?? 0

    readonly property string micIcon: micMuted || micVolume <= 0.001 ? "" : ""

    readonly property string icon: muted || volume <= 0.001
        ? ""
        : volume < 0.34 ? ""
        : volume < 0.67 ? ""
        : ""

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function setMicVolume(v) {
        if (source?.audio)
            source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function nudge(delta) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMic() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }
}
