pragma Singleton

import Quickshell

// SF Symbols glyphs from the SF Pro font (private use area, U+100000 + n).
// Codepoints found by rendering the font; names are the SF Symbols names.
Singleton {
    function sf(n) { return String.fromCodePoint(0x100000 + n) }

    readonly property string wifi: sf(0x647)          // wifi
    readonly property string wifiOff: sf(0x648)       // wifi.slash
    // not in SF Symbols: Material Design glyphs, which fontconfig falls back to the Nerd Font for
    readonly property string bt: "\u{f00af}"      // nf-md-bluetooth
    readonly property string btOff: "\u{f00b2}"   // nf-md-bluetooth_off
    readonly property string lan: sf(0x886)           // point.3.filled.connected.trianglepath.dotted
    readonly property string vpn: sf(0x667)           // shield.fill
    readonly property string vol: sf(0x2A7)           // speaker.wave.2.fill
    readonly property string volOff: sf(0x2A3)        // speaker.slash.fill
    readonly property string mic: sf(0x2B1)           // mic.fill
    readonly property string micOff: sf(0x2B3)        // mic.slash.fill
    readonly property string prev: sf(0x28A)          // backward.fill
    readonly property string next: sf(0x28C)          // forward.fill
    readonly property string play: sf(0x284)          // play.fill
    readonly property string pause: sf(0x286)         // pause.fill
    readonly property string battery: sf(0x6E8)       // battery.100
    readonly property string charging: sf(0x2E6)      // bolt.fill
    readonly property string lock: sf(0x3A1)          // lock.fill
    readonly property string check: sf(0x185)         // checkmark
    readonly property string refresh: sf(0x148)       // arrow.clockwise
    readonly property string saver: sf(0x973)         // leaf.fill
    readonly property string balanced: sf(0x2)        // circle.lefthalf.filled
    readonly property string performance: sf(0x2E6)   // bolt.fill
    readonly property string music: sf(0x46A)         // music.note
    readonly property string search: sf(0x2AD)        // magnifyingglass
    readonly property string sun: sf(0x1AD)           // sun.max
}
