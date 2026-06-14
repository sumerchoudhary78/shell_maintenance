pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.components.containers
import qs.services
import qs.utils

Scope {
    id: root

    // User config (optional). Overridable live via
    // ~/.config/caelestia/claude-indicator.json; sensible defaults otherwise.
    QtObject {
        id: cfg

        property bool enabled: true
        property bool alwaysOn: true // peek at home when idle; false = only while Claude works
        property string homeSide: "right"
        property real sizeScale: 1
        property real speedScale: 1
        property bool dance: true
        property bool fight: true
        property bool bubbles: true

        function apply(txt: string): void {
            try {
                const j = JSON.parse(txt);
                if (typeof j.enabled === "boolean")
                    enabled = j.enabled;
                if (typeof j.alwaysOn === "boolean")
                    alwaysOn = j.alwaysOn;
                if (j.homeSide === "left" || j.homeSide === "right")
                    homeSide = j.homeSide;
                if (typeof j.sizeScale === "number")
                    sizeScale = Math.max(0.4, Math.min(3, j.sizeScale));
                if (typeof j.speedScale === "number")
                    speedScale = Math.max(0.2, Math.min(4, j.speedScale));
                if (typeof j.dance === "boolean")
                    dance = j.dance;
                if (typeof j.fight === "boolean")
                    fight = j.fight;
                if (typeof j.bubbles === "boolean")
                    bubbles = j.bubbles;
            } catch (e) {}
        }
    }

    FileView {
        path: `${Paths.config}/claude-indicator.json`
        watchChanges: true
        onLoaded: cfg.apply(text())
        onFileChanged: reload()
    }

    Loader {
        active: cfg.enabled && (cfg.alwaysOn || Claude.working)
        asynchronous: true

        sourceComponent: StyledWindow {
            id: win

            // Director state for the summon-on-demand dance / fight
            property string dirMode: "none" // none|dance|fight
            property string dirPhase: ""
            property real dirT: 0
            property real phaseT: 0
            property int clashCount: 0
            property bool dirEnding: false
            property real winClock: 0
            property real sparkUntil: -1
            property real sparkX: 0
            property real sparkY: 0
            property bool menuShown: false

            readonly property real groundY: height - 6
            readonly property real pxScale: Math.max(0.6, Math.min(2.2, (screen?.height ?? 1080) / 1080)) * cfg.sizeScale
            readonly property bool routineActive: dirMode !== "none"
            readonly property bool dragging: primary.state === "dragging"
            readonly property var second: agent2Loader.item
            readonly property bool moving: primary.busy || (second && second.busy) || routineActive

            // Interaction geometry (window coords), tracking the primary mascot
            readonly property real dbX: primary.charX - 70 * pxScale
            readonly property real dbY: primary.pipY - 165 * pxScale
            readonly property real dbW: 140 * pxScale
            readonly property real dbH: 182 * pxScale
            readonly property real menuW: 214
            readonly property real menuH: 32
            readonly property real menuX: Math.max(6, Math.min(width - menuW - 6, primary.charX - menuW / 2))
            readonly property real menuY: dbY - 12 - menuH
            readonly property bool menuOpen: menuShown && !routineActive && !dragging

            // Input region: empty during routines (full click-through), the
            // whole window while dragging, otherwise the mascot box — grown to
            // include the menu while it's open so the buttons are reachable.
            readonly property real boxX: dragging ? 0 : routineActive ? 0 : menuOpen ? Math.min(dbX, menuX) : dbX
            readonly property real boxY: dragging ? 0 : routineActive ? 0 : menuOpen ? menuY : dbY
            readonly property real boxW: dragging ? width : routineActive ? 0 : menuOpen ? Math.max(dbX + dbW, menuX + menuW) - boxX : dbW
            readonly property real boxH: dragging ? height : routineActive ? 0 : menuOpen ? dbY + dbH - boxY : dbH

            function spark(x: real, y: real): void {
                sparkX = x;
                sparkY = y;
                sparkUntil = winClock + 0.22;
            }

            function startDance(): void {
                if (routineActive)
                    return;
                menuShown = false;
                dirMode = "dance";
                dirT = 0;
                dirEnding = false;
                show2nd();
                primary.behavior = "dance";
            }

            function startFight(): void {
                if (routineActive)
                    return;
                menuShown = false;
                dirMode = "fight";
                dirPhase = "approach";
                dirT = 0;
                phaseT = 0;
                clashCount = 0;
                show2nd();
                primary.behavior = "fight";
            }

            function show2nd(): void {
                agent2Loader.active = true;
                if (second)
                    second.behavior = dirMode;
            }

            function endRoutine(): void {
                primary.behavior = "auto";
                if (primary.state !== "dragging")
                    primary.state = "walking";
                dirMode = "none";
                dirEnding = false;
                agent2Loader.active = false;
            }

            function director(dt: real): void {
                if (dirMode === "none" || !second)
                    return;
                dirT += dt;
                const center = width / 2;

                if (dirMode === "dance") {
                    second.behavior = dirEnding ? "exit" : "dance";
                    primary.behavior = dirEnding ? "auto" : "dance";
                    if (!dirEnding) {
                        const c = Math.min(width - 170, Math.max(170, primary.charX));
                        primary.targetX = c + 72;
                        second.targetX = c - 72;
                        if (dirT > 9)
                            dirEnding = true;
                    } else {
                        if (primary.state !== "walking" && primary.state !== "turning" && primary.state !== "idling")
                            primary.state = "walking";
                        if (second.exited)
                            endRoutine();
                    }
                } else if (dirMode === "fight") {
                    primary.opponentX = second.charX;
                    second.opponentX = primary.charX;
                    if (dirPhase === "approach") {
                        primary.behavior = "fight";
                        second.behavior = "fight";
                        primary.targetX = center + 92;
                        second.targetX = center - 92;
                        if (Math.abs(primary.charX - (center + 92)) < 16 && Math.abs(second.charX - (center - 92)) < 16) {
                            dirPhase = "clashIn";
                            phaseT = dirT;
                        }
                    } else if (dirPhase === "clashIn") {
                        primary.targetX = center + 28;
                        second.targetX = center - 28;
                        if (dirT - phaseT > 0.16) {
                            spark(center, primary.pipY - 78);
                            clashCount++;
                            dirPhase = "clashOut";
                            phaseT = dirT;
                        }
                    } else if (dirPhase === "clashOut") {
                        primary.targetX = center + 96;
                        second.targetX = center - 96;
                        if (dirT - phaseT > 0.34) {
                            if (clashCount >= 5) {
                                dirPhase = "end";
                                phaseT = dirT;
                            } else {
                                dirPhase = "clashIn";
                                phaseT = dirT;
                            }
                        }
                    } else if (dirPhase === "end") {
                        second.behavior = "exit";
                        primary.behavior = "auto";
                        if (primary.state !== "walking" && primary.state !== "turning" && primary.state !== "idling")
                            primary.state = "walking";
                        if (second.exited)
                            endRoutine();
                    }
                }
            }

            function step(dt: real): void {
                winClock += dt;
                primary.tick(dt);
                if (second)
                    second.tick(dt);
                director(dt);
            }

            name: "claudeindicator"
            screen: Quickshell.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0]
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            mask: Region {
                x: win.boxX
                y: win.boxY
                width: win.boxW
                height: win.boxH
            }

            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true

            // Vsync-smooth ticking only while something moves; a slow timer
            // keeps idle/peek poses (breath, blink, zzz) alive at ~12fps so a
            // dozing mascot costs almost nothing.
            FrameAnimation {
                running: win.moving
                onTriggered: win.step(frameTime)
            }

            Timer {
                running: !win.moving
                interval: 80
                repeat: true
                onTriggered: win.step(0.08)
            }

            PipAgent {
                id: primary

                areaWidth: win.width
                groundY: win.groundY
                isPrimary: true
                active: Claude.working
                autoHome: cfg.alwaysOn
                homeSide: cfg.homeSide
                pxScale: win.pxScale
                speedScale: cfg.speedScale
            }

            Loader {
                id: agent2Loader

                active: false

                sourceComponent: PipAgent {
                    areaWidth: win.width
                    groundY: win.groundY
                    isPrimary: false
                    autoHome: false
                    homeSide: cfg.homeSide
                    pxScale: win.pxScale
                    speedScale: cfg.speedScale
                    Component.onCompleted: {
                        charX = cfg.homeSide === "left" ? -60 : win.width + 60; // enter from off the far edge
                        pipY = win.groundY;
                        started = true;
                        exited = false;
                        behavior = win.dirMode;
                    }
                }
            }

            // Hit spark during fight clashes
            Item {
                id: sparkItem

                readonly property real life: (win.sparkUntil - win.winClock) / 0.22

                x: win.sparkX
                y: win.sparkY
                visible: life > 0 && life <= 1
                opacity: visible ? Math.min(1, life * 1.4) : 0
                scale: visible ? 1.5 - 0.5 * life : 1

                Repeater {
                    model: 8

                    Rectangle {
                        required property int index

                        width: index % 2 === 0 ? 26 : 16
                        height: 3
                        radius: 1.5
                        color: "#ffd34d"
                        antialiasing: true
                        x: -width / 2
                        y: -height / 2
                        rotation: index * 45
                        transformOrigin: Item.Center
                    }
                }
            }

            // Speech bubble (primary)
            Item {
                id: bubble

                readonly property real maxW: 240

                x: Math.max(6, Math.min(win.width - width - 6, primary.charX - width / 2))
                y: win.dbY - 5 - height
                width: card.width
                height: card.height + 7
                visible: opacity > 0.01
                opacity: cfg.bubbles && primary.bubbleText !== "" && !win.routineActive ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                }

                Rectangle {
                    id: card

                    width: label.width + 22
                    height: label.implicitHeight + 14
                    radius: 12
                    color: "#f7f4ee"
                    border.color: "#3fb0795f"
                    border.width: 1

                    Text {
                        id: label

                        anchors.centerIn: parent
                        width: Math.min(bubble.maxW - 22, implicitWidth)
                        text: primary.bubbleText
                        color: "#33302b"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    width: 12
                    height: 12
                    color: "#f7f4ee"
                    rotation: 45
                    x: card.width / 2 - 6
                    y: card.height - 6
                }
            }

            // Drag + hover handling on the mascot
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: mouse => {
                    if (!win.routineActive && mouse.y >= win.dbY - 12 && mouse.y <= win.dbY + win.dbH)
                        primary.beginDrag(mouse.x, mouse.y);
                }
                onReleased: primary.endDrag()
                onPositionChanged: mouse => {
                    if (primary.state === "dragging")
                        primary.dragTo(mouse.x, mouse.y);
                }
                onContainsMouseChanged: {
                    if (containsMouse) {
                        hideTimer.stop();
                        if (!win.routineActive)
                            win.menuShown = true;
                    } else {
                        hideTimer.restart();
                    }
                }

                Timer {
                    id: hideTimer

                    interval: 240
                    onTriggered: win.menuShown = false
                }
            }

            // Hover action menu
            Row {
                id: menu

                x: win.menuX
                y: win.menuY
                height: win.menuH
                spacing: 6
                visible: win.menuOpen

                Repeater {
                    model: {
                        const m = [];
                        if (cfg.alwaysOn)
                            m.push("Go home");
                        if (cfg.dance)
                            m.push("Dance");
                        if (cfg.fight)
                            m.push("Fight");
                        return m;
                    }

                    Rectangle {
                        id: btn

                        required property string modelData

                        width: lbl.implicitWidth + 18
                        height: win.menuH
                        radius: 9
                        color: ma.containsMouse ? "#ffffff" : "#f3efe7"
                        border.color: "#40b0795f"
                        border.width: 1

                        Text {
                            id: lbl

                            anchors.centerIn: parent
                            text: btn.modelData
                            color: "#33302b"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: ma

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (btn.modelData === "Go home")
                                    primary.goHome();
                                else if (btn.modelData === "Dance")
                                    win.startDance();
                                else
                                    win.startFight();
                                win.menuShown = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
