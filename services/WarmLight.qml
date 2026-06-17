pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components.misc
import qs.services

Singleton {
    id: root

    // Kelvin bounds. 6500K is the neutral/identity point (filter effectively off).
    readonly property int minTemperature: 1000
    readonly property int maxTemperature: 6500

    // Config-derived schedule/temperature settings
    readonly property bool autoEnabled: GlobalConfig.services.warmLightAuto
    readonly property int nightTemp: clampTemp(GlobalConfig.services.warmLightNightTemperature)
    readonly property int dayTemp: clampTemp(GlobalConfig.services.warmLightDayTemperature)
    readonly property int step: GlobalConfig.services.warmLightStep
    readonly property int startHour: GlobalConfig.services.warmLightStartHour
    readonly property int endHour: GlobalConfig.services.warmLightEndHour

    // Whether the current hour falls inside the night window. Handles wrap past midnight.
    readonly property bool isNight: {
        const h = Time.hours;
        if (startHour === endHour)
            return false;
        if (startHour < endHour)
            return h >= startHour && h < endHour;
        return h >= startHour || h < endHour;
    }

    // Manual state, persisted across shell reloads (source of truth — hyprsunset can't be queried reliably)
    property alias manualEnabled: props.manualEnabled
    property alias manualTemperature: props.manualTemperature

    // Effective state actually pushed to hyprsunset
    readonly property bool active: autoEnabled ? isNight : manualEnabled
    readonly property int temperature: active ? (autoEnabled ? nightTemp : clampTemp(manualTemperature)) : maxTemperature

    function clampTemp(t: int): int {
        return Math.max(minTemperature, Math.min(maxTemperature, Math.round(t)));
    }

    function toggle(): void {
        props.manualEnabled = !props.manualEnabled;
    }

    function enable(): void {
        props.manualEnabled = true;
    }

    function disable(): void {
        props.manualEnabled = false;
    }

    function setTemperature(t: int): void {
        props.manualTemperature = clampTemp(t);
        if (!autoEnabled)
            props.manualEnabled = true;
    }

    // Lower Kelvin = warmer
    function warmer(): void {
        setTemperature(manualTemperature - step);
    }

    function cooler(): void {
        setTemperature(manualTemperature + step);
    }

    function apply(): void {
        if (temperature >= maxTemperature)
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
        else
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(temperature)]);
    }

    onTemperatureChanged: apply()
    Component.onCompleted: daemonCheck.running = true

    PersistentProperties {
        id: props

        property bool manualEnabled: false
        property int manualTemperature: 4000

        reloadableId: "warmLight"
    }

    // Start the hyprsunset daemon if it isn't already up, then push our current state.
    Process {
        id: daemonCheck

        command: ["pidof", "-x", "hyprsunset"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0)
                    Quickshell.execDetached(["hyprsunset"]);
                applyTimer.restart();
            }
        }
    }

    // Give a freshly-spawned daemon a moment to bind before we send IPC
    Timer {
        id: applyTimer

        interval: 500
        onTriggered: root.apply()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "warmLightToggle"
        description: "Toggle warm light"
        onPressed: root.toggle()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "warmLightWarmer"
        description: "Make screen warmer (lower colour temperature)"
        onPressed: root.warmer()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "warmLightCooler"
        description: "Make screen cooler (raise colour temperature)"
        onPressed: root.cooler()
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.active;
        }

        function toggle(): void {
            root.toggle();
        }

        function enable(): void {
            root.enable();
        }

        function disable(): void {
            root.disable();
        }

        function get(): int {
            return root.temperature;
        }

        function set(value: int): string {
            root.setTemperature(value);
            return `Set warm light to ${root.temperature}K`;
        }

        function warmer(): void {
            root.warmer();
        }

        function cooler(): void {
            root.cooler();
        }

        target: "warmLight"
    }
}
