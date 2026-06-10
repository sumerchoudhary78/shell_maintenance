pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.components.containers
import qs.services

Scope {
    id: root

    Connections {
        function onWorkingChanged(): void {
            if (!Claude.working)
                linger.restart();
        }

        target: Claude
    }

    Timer {
        id: linger

        // keep the window alive long enough for the hide animation
        interval: 600
    }

    Loader {
        active: Claude.working || linger.running
        asynchronous: true

        sourceComponent: StyledWindow {
            id: win

            readonly property real walkSpeed: 0.075 // px per ms

            name: "claudeindicator"
            screen: Quickshell.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0]
            implicitHeight: 150
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            anchors.left: true
            anchors.right: true
            anchors.bottom: true

            Clawd3D {
                id: clawd

                property bool shown: false

                width: 170
                height: 150
                animating: Claude.working
                opacity: shown && Claude.working ? 1 : 0
                scale: shown && Claude.working ? 1 : 0.4
                transformOrigin: Item.Bottom
                Component.onCompleted: shown = true

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Behavior on scale {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }

            SequentialAnimation {
                running: Claude.working
                loops: Animation.Infinite

                ScriptAction {
                    script: clawd.facing = 1
                }

                NumberAnimation {
                    target: clawd
                    property: "x"
                    to: win.width - clawd.width
                    duration: Math.max(1000, (win.width - clawd.width) / win.walkSpeed)
                }

                PauseAnimation {
                    duration: 500
                }

                ScriptAction {
                    script: clawd.facing = -1
                }

                NumberAnimation {
                    target: clawd
                    property: "x"
                    to: 0
                    duration: Math.max(1000, (win.width - clawd.width) / win.walkSpeed)
                }

                PauseAnimation {
                    duration: 500
                }
            }
        }
    }
}
