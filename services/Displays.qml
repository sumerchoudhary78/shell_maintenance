pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

Singleton {
    id: root

    // Full monitor list incl. disabled ones (`hyprctl monitors all -j`).
    // Quickshell's Hyprland.monitors omits disabled outputs, so we poll directly.
    property var monitors: []
    readonly property int activeCount: monitors.filter(m => !m.disabled).length

    // Repoll whenever a monitor is plugged/unplugged.
    readonly property int liveCount: Hyprland.monitors.values.length

    signal changed

    function refresh(): void {
        proc.running = false;
        proc.running = true;
    }

    function monitorByName(name: string): var {
        return monitors.find(m => m.name === name) ?? null;
    }

    function otherActive(name: string): var {
        return monitors.filter(m => !m.disabled && m.name !== name);
    }

    // Build a full `monitor` keyword spec from a monitor's current state, applying
    // overrides. Hyprland replaces the whole spec, so unchanged fields must be kept.
    function buildSpec(mon: var, o: var): string {
        o = o ?? ({});
        const res = o.res ?? `${mon.width}x${mon.height}@${mon.refreshRate.toFixed(2)}`;
        const pos = o.pos ?? `${mon.x}x${mon.y}`;
        const scale = o.scale ?? mon.scale;
        let spec = `${mon.name},${res},${pos},${scale}`;

        const transform = o.transform ?? mon.transform;
        if (transform)
            spec += `,transform,${transform}`;

        const mirror = o.mirror !== undefined ? o.mirror : (mon.mirrorOf && mon.mirrorOf !== "none" ? mon.mirrorOf : null);
        if (mirror)
            spec += `,mirror,${mirror}`;

        return spec;
    }

    function apply(spec: string): void {
        Hypr.extras.batchMessage([`keyword monitor ${spec}`]);
        debounce.restart();
    }

    function setMode(name: string, mode: string): void {
        const mon = monitorByName(name);
        if (mon)
            apply(buildSpec(mon, {
                res: mode.replace("Hz", "").trim()
            }));
    }

    function setScale(name: string, scale: real): void {
        const mon = monitorByName(name);
        if (mon)
            apply(buildSpec(mon, {
                scale: scale.toFixed(6).replace(/0+$/, "").replace(/\.$/, "")
            }));
    }

    function setTransform(name: string, transform: int): void {
        const mon = monitorByName(name);
        if (mon)
            apply(buildSpec(mon, {
                transform
            }));
    }

    function setPosition(name: string, x: int, y: int): void {
        const mon = monitorByName(name);
        if (mon)
            apply(buildSpec(mon, {
                pos: `${Math.round(x)}x${Math.round(y)}`
            }));
    }

    function setAutoPosition(name: string): void {
        const mon = monitorByName(name);
        if (mon)
            apply(buildSpec(mon, {
                pos: "auto"
            }));
    }

    // target === null clears mirroring (re-applies the spec without a mirror clause).
    function setMirror(name: string, target: string): void {
        const mon = monitorByName(name);
        if (mon)
            apply(buildSpec(mon, {
                mirror: target ?? null
            }));
    }

    function setEnabled(name: string, on: bool): void {
        if (!on) {
            // Never black out the last active output.
            if (activeCount <= 1)
                return;
            Hypr.extras.batchMessage([`keyword monitor ${name},disable`]);
            debounce.restart();
        } else {
            Hypr.extras.batchMessage([`keyword monitor ${name},preferred,auto,1`]);
            debounce.restart();
        }
    }

    // Reset a monitor to its preferred mode, auto position, scale 1.
    function reset(name: string): void {
        Hypr.extras.batchMessage([`keyword monitor ${name},preferred,auto,1`]);
        debounce.restart();
    }

    function moveFocusedWindowTo(name: string): void {
        Hypr.dispatch(`movewindow mon:${name}`);
    }

    function moveCurrentWorkspaceTo(name: string): void {
        Hypr.dispatch(`movecurrentworkspacetomonitor ${name}`);
    }

    function parse(text: string): void {
        try {
            const arr = JSON.parse(text);
            root.monitors = arr.map(m => ({
                        name: m.name,
                        id: m.id,
                        description: m.description ?? "",
                        make: m.make ?? "",
                        model: m.model ?? "",
                        disabled: m.disabled ?? false,
                        width: m.width ?? 0,
                        height: m.height ?? 0,
                        refreshRate: m.refreshRate ?? 0,
                        x: m.x ?? 0,
                        y: m.y ?? 0,
                        scale: m.scale ?? 1,
                        transform: m.transform ?? 0,
                        mirrorOf: m.mirrorOf ?? "none",
                        focused: m.focused ?? false,
                        activeWorkspace: m.activeWorkspace ?? null,
                        availableModes: m.availableModes ?? []
                    }));
            root.changed();
        } catch (e) {
            // Ignore transient parse failures (hyprctl racing a reconfigure).
        }
    }

    onLiveCountChanged: refresh()
    Component.onCompleted: refresh()

    Process {
        id: proc

        command: ["hyprctl", "monitors", "all", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        id: debounce

        interval: 300
        onTriggered: root.refresh()
    }
}
