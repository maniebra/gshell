//@ pragma IconTheme WhiteSur-dark
import Quickshell
import QtQuick
import qs.Sections
import qs.Services

ShellRoot {
    // singletons load lazily; start clipboard history recording now
    Component.onCompleted: Clipboard.max
    Desktop {}
    Bar {}
    Dock {}
    Osd {}
    Toasts {}
    Island {}
    ControlCenter {}
    Dashboard {}
    Launcher {}
}
