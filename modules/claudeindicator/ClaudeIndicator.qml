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

            name: "claudeindicator"
            screen: Quickshell.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0]
            implicitWidth: 160
            implicitHeight: 160
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            anchors.top: true
            anchors.right: true
            margins.top: 12
            margins.right: 12

            Logo3D {
                id: logo

                property bool shown: false

                anchors.fill: parent
                spinning: Claude.working
                opacity: shown && Claude.working ? 1 : 0
                scale: shown && Claude.working ? 1 : 0.4
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
        }
    }
}
