pragma Singleton

import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available:
        device?.isLaptopBattery ?? false

    readonly property real level: {
        const p = device?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }

    readonly property int percent: Math.round(level * 100)

    readonly property bool charging:
        device?.state === UPowerDeviceState.Charging
        || device?.state === UPowerDeviceState.FullyCharged

    readonly property bool low: !charging && level < 0.2

    readonly property string icon: {
        if (charging)
            return "";
        const steps = ["", "", "", "", "", "", "", "", "", "", ""];
        return steps[Math.min(10, Math.max(0, Math.round(level * 10)))];
    }

    readonly property string remaining: {
        const secs = charging
            ? (device?.timeToFull ?? 0)
            : (device?.timeToEmpty ?? 0);

        if (secs <= 0)
            return "";

        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
