pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property var monitors: []
    property string selected

    readonly property real pad: Tokens.padding.large
    readonly property real minX: monitors.length ? Math.min(...monitors.map(m => m.x)) : 0
    readonly property real minY: monitors.length ? Math.min(...monitors.map(m => m.y)) : 0
    readonly property real spanX: monitors.length ? Math.max(...monitors.map(m => m.x + logicalW(m))) - minX : 1
    readonly property real spanY: monitors.length ? Math.max(...monitors.map(m => m.y + logicalH(m))) - minY : 1
    readonly property real sf: Math.min((width - pad * 2) / spanX, (height - pad * 2) / spanY)
    readonly property real offsetX: (width - spanX * sf) / 2 - minX * sf
    readonly property real offsetY: (height - spanY * sf) / 2 - minY * sf

    signal selectMonitor(name: string)

    // Logical (post-scale) sizes, accounting for 90/270° rotation swapping w/h.
    function logicalW(m: var): real {
        const w = (m.width > 0 ? m.width : 1920) / (m.scale || 1);
        const h = (m.height > 0 ? m.height : 1080) / (m.scale || 1);
        return (m.transform === 1 || m.transform === 3 || m.transform === 5 || m.transform === 7) ? h : w;
    }

    function logicalH(m: var): real {
        const w = (m.width > 0 ? m.width : 1920) / (m.scale || 1);
        const h = (m.height > 0 ? m.height : 1080) / (m.scale || 1);
        return (m.transform === 1 || m.transform === 3 || m.transform === 5 || m.transform === 7) ? w : h;
    }

    implicitHeight: 170

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerLow

        Repeater {
            model: root.monitors

            StyledRect {
                id: rect

                required property var modelData

                readonly property bool isSelected: modelData.name === root.selected

                x: root.offsetX + modelData.x * root.sf
                y: root.offsetY + modelData.y * root.sf
                implicitWidth: Math.max(48, root.logicalW(modelData) * root.sf)
                implicitHeight: Math.max(32, root.logicalH(modelData) * root.sf)

                radius: Tokens.rounding.small
                color: rect.isSelected ? Colours.palette.m3primaryContainer : (modelData.disabled ? Colours.tPalette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh)
                border.width: rect.isSelected ? 2 : 1
                border.color: rect.isSelected ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                opacity: modelData.disabled ? 0.55 : 1

                Behavior on color {
                    CAnim {}
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: rect.modelData.name
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: rect.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: rect.implicitHeight > 50
                        text: rect.modelData.disabled ? qsTr("Off") : `${rect.modelData.width}×${rect.modelData.height}`
                        font: Tokens.font.label.small
                        color: rect.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectMonitor(rect.modelData.name)
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.monitors.length === 0
            text: qsTr("No displays detected")
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
