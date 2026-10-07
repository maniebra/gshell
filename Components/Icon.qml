import QtQuick
import qs.Utils

Text {
    color: Theme.fg
    // Material Design glyphs (U+F0000 plane) come from the Nerd Font; SF Pro
    // has its own glyphs there, so plain fallback would pick the wrong one
    font.family: { const c = text.codePointAt(0); return c >= 0xF0000 && c < 0x100000 ? "JetBrainsMono Nerd Font" : Theme.iconFont }
    font.pixelSize: 18
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
