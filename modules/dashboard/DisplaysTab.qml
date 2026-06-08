pragma ComponentBehavior: Bound

import "displays"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.modules.nexus.common

Item {
    id: root

    // User's explicit pick; falls back to the focused/first monitor.
    property string picked
    readonly property string activeName: picked && Displays.monitorByName(picked) ? picked : ((Displays.monitors.find(m => m.focused) ?? Displays.monitors[0])?.name ?? "")
    readonly property var mon: Displays.monitorByName(activeName)
    readonly property string currentMode: mon ? `${mon.width}x${mon.height}@${mon.refreshRate.toFixed(2)}` : ""

    // Cap height so the dashboard never runs off-screen; content scrolls beyond.
    readonly property real maxHeight: 780

    implicitWidth: 840
    implicitHeight: Math.min(content.implicitHeight, maxHeight)

    Component.onCompleted: Displays.refresh()

    Variants {
        id: modeInst

        model: root.mon?.availableModes ?? []

        MenuItem {
            required property var modelData

            text: modelData.replace("Hz", "").trim()
        }
    }

    Variants {
        id: orientInst

        model: [
            {
                text: qsTr("Landscape"),
                value: 0
            },
            {
                text: qsTr("Portrait — 90°"),
                value: 1
            },
            {
                text: qsTr("Landscape flipped — 180°"),
                value: 2
            },
            {
                text: qsTr("Portrait — 270°"),
                value: 3
            }
        ]

        OrientItem {}
    }

    Variants {
        id: mirrorInst

        model: [
            {
                name: "",
                label: qsTr("None")
            }
        ].concat(Displays.otherActive(root.activeName).map(m => ({
                    name: m.name,
                    label: m.name
                })))

        MirrorItem {}
    }

    Variants {
        id: targetWinInst

        model: Displays.monitors.filter(m => !m.disabled)

        MenuItem {
            required property var modelData

            text: modelData.name
        }
    }

    Variants {
        id: targetWsInst

        model: Displays.monitors.filter(m => !m.disabled)

        MenuItem {
            required property var modelData

            text: modelData.name
        }
    }

    VerticalFadeFlickable {
        anchors.fill: parent

        contentHeight: content.implicitHeight

        ColumnLayout {
            id: content

            width: root.width
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.large
                Layout.rightMargin: Tokens.padding.large

                StyledText {
                    text: qsTr("Displays")
                    font: Tokens.font.body.builders.large.size(28).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    icon: "refresh"
                    onClicked: Displays.refresh()
                }
            }

            MonitorMap {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.large
                Layout.rightMargin: Tokens.padding.large

                monitors: Displays.monitors
                selected: root.activeName
                onSelectMonitor: name => root.picked = name
            }

            // --- Selected output -----------------------------------------
            SectionHeader {
                visible: !!root.mon
                text: root.mon ? qsTr("Output — %1").arg(root.mon.name) : ""
            }

            ToggleRow {
                Layout.fillWidth: true
                visible: !!root.mon
                first: true

                text: qsTr("Enabled")
                subtext: Displays.activeCount <= 1 && !(root.mon?.disabled ?? false) ? qsTr("Can't disable the only active display") : qsTr("Turn this output on or off")
                checked: !(root.mon?.disabled ?? false)
                enabled: !(Displays.activeCount <= 1 && !(root.mon?.disabled ?? false))
                onToggled: Displays.setEnabled(root.activeName, checked)
            }

            SelectRow {
                Layout.fillWidth: true
                visible: !!root.mon && !(root.mon?.disabled ?? false)

                label: qsTr("Resolution")
                subtext: qsTr("Resolution and refresh rate")
                menuItems: modeInst.instances
                active: menuItems.find(i => i.text === root.currentMode) ?? null
                fallbackText: root.currentMode || qsTr("Unknown")
                onSelected: item => Displays.setMode(root.activeName, item.text)
            }

            StepperRow {
                Layout.fillWidth: true
                visible: !!root.mon && !(root.mon?.disabled ?? false)

                label: qsTr("Scale")
                subtext: qsTr("Fractional scaling (Hyprland may reject non-integer pixel sizes)")
                value: root.mon?.scale ?? 1
                from: 0.5
                to: 3
                stepSize: 0.05
                onMoved: v => Displays.setScale(root.activeName, v)
            }

            SelectRow {
                Layout.fillWidth: true
                visible: !!root.mon && !(root.mon?.disabled ?? false)

                label: qsTr("Orientation")
                subtext: qsTr("Rotate the output")
                menuItems: orientInst.instances
                active: menuItems.find(i => (i as OrientItem).value === (root.mon?.transform ?? 0)) ?? menuItems[0] ?? null
                onSelected: item => Displays.setTransform(root.activeName, (item as OrientItem).value)
            }

            SelectRow {
                Layout.fillWidth: true
                visible: !!root.mon && !(root.mon?.disabled ?? false) && Displays.activeCount > 1

                label: qsTr("Mirror")
                subtext: qsTr("Show another display's contents on this one")
                menuItems: mirrorInst.instances
                active: menuItems.find(i => (i as MirrorItem).monName === (root.mon && root.mon.mirrorOf !== "none" ? root.mon.mirrorOf : "")) ?? menuItems[0] ?? null
                onSelected: item => Displays.setMirror(root.activeName, (item as MirrorItem).monName || null)
            }

            // --- Position ------------------------------------------------
            SectionHeader {
                visible: !!root.mon && !(root.mon?.disabled ?? false)
                text: qsTr("Position")
            }

            StepperRow {
                Layout.fillWidth: true
                visible: !!root.mon && !(root.mon?.disabled ?? false)
                first: true

                label: qsTr("X offset")
                value: root.mon?.x ?? 0
                from: -20000
                to: 20000
                stepSize: 10
                onMoved: v => Displays.setPosition(root.activeName, v, root.mon?.y ?? 0)
            }

            StepperRow {
                Layout.fillWidth: true
                visible: !!root.mon && !(root.mon?.disabled ?? false)

                label: qsTr("Y offset")
                value: root.mon?.y ?? 0
                from: -20000
                to: 20000
                stepSize: 10
                onMoved: v => Displays.setPosition(root.activeName, root.mon?.x ?? 0, v)
            }

            ConnectedRect {
                Layout.fillWidth: true
                visible: !!root.mon && !(root.mon?.disabled ?? false)
                last: true

                implicitHeight: autoRow.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: autoRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    anchors.topMargin: Tokens.padding.medium
                    anchors.bottomMargin: Tokens.padding.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Auto-arrange this output")
                        font: Tokens.font.body.small
                    }

                    TextButton {
                        text: qsTr("Auto")
                        onClicked: Displays.setAutoPosition(root.activeName)
                    }
                }
            }

            // --- Move apps between displays ------------------------------
            SectionHeader {
                visible: Displays.activeCount > 1
                text: qsTr("Move to display")
            }

            SelectRow {
                Layout.fillWidth: true
                visible: Displays.activeCount > 1
                first: true

                label: qsTr("Send focused window to")
                subtext: qsTr("Moves the currently focused window")
                menuItems: targetWinInst.instances
                active: null
                fallbackText: qsTr("Choose display")
                fallbackIcon: "monitor"
                onSelected: item => Displays.moveFocusedWindowTo(item.text)
            }

            SelectRow {
                Layout.fillWidth: true
                visible: Displays.activeCount > 1
                last: true

                label: qsTr("Send current workspace to")
                subtext: qsTr("Moves the active workspace and all its windows")
                menuItems: targetWsInst.instances
                active: null
                fallbackText: qsTr("Choose display")
                fallbackIcon: "desktop_windows"
                onSelected: item => Displays.moveCurrentWorkspaceTo(item.text)
            }
        }
    }

    component OrientItem: MenuItem {
        required property var modelData

        readonly property int value: modelData.value

        text: modelData.text
    }

    component MirrorItem: MenuItem {
        required property var modelData

        readonly property string monName: modelData.name

        text: modelData.label
    }
}
