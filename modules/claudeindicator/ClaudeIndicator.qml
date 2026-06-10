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

            readonly property real walkSpeed: 0.09 // px per ms

            function wander(): void {
                const tx = Math.random() * Math.max(1, width - holder.width);
                const ty = Math.random() * Math.max(1, height - holder.height);
                if (Math.abs(tx - holder.x) > 8)
                    clawd.facing = tx >= holder.x ? 1 : -1;
                const duration = Math.max(500, Math.hypot(tx - holder.x, ty - holder.y) / walkSpeed);
                moveX.to = tx;
                moveX.duration = duration;
                moveY.to = ty;
                moveY.duration = duration;
                clawd.walking = true;
                moveAnim.restart();
            }

            function arrive(): void {
                clawd.walking = false;

                // he noticed something: look around, wave at it, hop, spin or just stare
                const r = Math.random();
                if (r < 0.25)
                    clawd.lookAround();
                else if (r < 0.45)
                    clawd.wave();
                else if (r < 0.6)
                    clawd.hop();
                else if (r < 0.72)
                    clawd.spin();
                idleTimer.interval = 1500 + Math.random() * 3000;
                idleTimer.restart();
            }

            name: "claudeindicator"
            screen: Quickshell.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0]
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            onWidthChanged: {
                if (width > 0 && !holder.started) {
                    holder.started = true;
                    holder.x = Math.random() * (width - holder.width);
                    holder.y = Math.random() * (height - holder.height);
                    wander();
                }
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Timer {
                id: idleTimer

                onTriggered: win.wander()
            }

            Item {
                id: holder

                property bool started: false

                width: 170
                height: 150

                // walking up the screen reads as walking away
                transform: Scale {
                    origin.x: holder.width / 2
                    origin.y: holder.height
                    xScale: 0.55 + 0.45 * (holder.y / Math.max(1, win.height - holder.height))
                    yScale: 0.55 + 0.45 * (holder.y / Math.max(1, win.height - holder.height))
                }

                Clawd3D {
                    id: clawd

                    property bool shown: false

                    anchors.fill: parent
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

                ParallelAnimation {
                    id: moveAnim

                    onFinished: win.arrive()

                    NumberAnimation {
                        id: moveX

                        target: holder
                        property: "x"
                    }

                    NumberAnimation {
                        id: moveY

                        target: holder
                        property: "y"
                    }
                }
            }
        }
    }
}
