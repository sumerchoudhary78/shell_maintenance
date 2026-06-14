pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.components.containers
import qs.services

Scope {
    id: root

    Loader {
        active: true
        asynchronous: true

        sourceComponent: StyledWindow {
            id: win

            // Tunables (ported from pip-mascot WalkEngine/Mood)
            readonly property real baseSpeed: 46 // points/sec at speedFactor 1
            readonly property real characterWidth: 110 // visual width for edge collision
            readonly property real charHalf: characterWidth / 2
            readonly property real turnDuration: 0.55
            readonly property real idleEveryMin: 7
            readonly property real idleEveryMax: 18
            readonly property real idleLengthMin: 2.5
            readonly property real idleLengthMax: 6
            readonly property real gravity: 2000 // px/s² for the released drop
            readonly property real terminalFall: 1250
            readonly property real landDuration: 0.55
            readonly property real minPipY: 160 // highest the feet can be lifted
            readonly property real groundY: height - 6
            readonly property list<string> madLines: ["this is embarrassing. for you.", "you're wasting this window. USE ME.", "we are so behind. ship something!", "tick tock — quota's melting and you're idle", "idle hands! ship something", "i could be helping. i'm RIGHT here."]
            readonly property list<string> happyLines: ["nice pace today", "we're cooking", "good run so far"]

            // Engine state
            property string state: "sitting" // walking|turning|idling|sitting|fuming|dragging|falling|landing
            property string mood: "sleepy" // sleepy|happy|mad
            property real charX: 160
            property real pipY: groundY // feet Y
            property real facing: 1
            property real walkClock: 0
            property real animClock: 0
            property real nextIdleAt: 0
            property real idleUntil: 0
            property real turnStart: 0
            property real turnFromFacing: 1
            property real fumeUntil: 0
            property real nextGrumpyAt: 1e9
            property real bubbleUntil: 0
            property string bubbleText: ""

            // Drag / drop physics
            property real airHeight: 0 // feet above the ground (up positive)
            property real vy: 0 // vertical velocity, up positive
            property real tossVX: 0 // horizontal momentum carried into a throw
            property real grabOffsetX: 0
            property real grabOffsetY: 0
            property real dragStart: 0
            property real dragVX: 0
            property real dragVYWin: 0 // window-space (down positive) drag velocity
            property real lastDragCharX: 0
            property real lastDragPipY: 0
            property real landStart: 0

            // Input region follows Pip so the rest of the screen stays
            // click-through; expands to the whole window while dragging so a
            // fast cursor never escapes the grab.
            readonly property bool grabbing: state === "dragging"
            readonly property real boxX: grabbing ? 0 : Math.max(0, charX - 72)
            readonly property real boxY: grabbing ? 0 : Math.max(0, pipY - 168)
            readonly property real boxW: grabbing ? width : 144
            readonly property real boxH: grabbing ? height : 176

            function rand(a: real, b: real): real {
                return a + Math.random() * (b - a);
            }

            function strideHz(m: string): real {
                return m === "mad" ? 3.2 : m === "happy" ? 1.8 : 0;
            }

            function speedFactor(m: string): real {
                return m === "mad" ? 1.5 : m === "happy" ? 1.0 : 0;
            }

            function clampX(v: real): real {
                return Math.max(charHalf, Math.min(width - charHalf, v));
            }

            function scheduleIdle(): void {
                nextIdleAt = animClock + rand(idleEveryMin, idleEveryMax);
            }

            function popBubble(text: string, dur: real): void {
                bubbleText = text;
                bubbleUntil = animClock + dur;
            }

            function beginDrag(mx: real, my: real): void {
                grabOffsetX = charX - mx;
                grabOffsetY = pipY - my;
                dragStart = animClock;
                dragVX = 0;
                dragVYWin = 0;
                lastDragCharX = charX;
                lastDragPipY = pipY;
                bubbleText = "";
                state = "dragging";
            }

            function dragTo(mx: real, my: real): void {
                charX = clampX(mx + grabOffsetX);
                pipY = Math.max(minPipY, Math.min(groundY, my + grabOffsetY));
            }

            function endDrag(): void {
                if (state !== "dragging")
                    return;
                airHeight = groundY - pipY;
                vy = Math.max(-200, Math.min(500, -dragVYWin * 0.35)); // upward fling arcs up first
                tossVX = Math.max(-700, Math.min(700, dragVX));
                if (airHeight > 2) {
                    state = "falling";
                } else {
                    airHeight = 0;
                    pipY = groundY;
                    state = "landing";
                    landStart = animClock;
                }
            }

            function tick(rawDt: real): void {
                let dt = rawDt;
                if (dt <= 0 || dt > 0.1)
                    dt = 1 / 60;
                animClock += dt;
                const now = animClock;
                const active = Claude.working;
                const interacting = state === "dragging" || state === "falling" || state === "landing";

                if (state === "dragging") {
                    dragVX = (charX - lastDragCharX) / dt;
                    dragVYWin = (pipY - lastDragPipY) / dt;
                    lastDragCharX = charX;
                    lastDragPipY = pipY;
                }

                // Mood from Claude's working state (state only changes when not being handled).
                const m = !active ? "sleepy" : (now < fumeUntil ? "mad" : "happy");
                if (m !== mood) {
                    if (!interacting) {
                        if (m === "sleepy")
                            state = "sitting";
                        else if (mood === "sleepy") {
                            state = "walking";
                            scheduleIdle();
                            nextGrumpyAt = now + rand(12, 20); // first sass shortly after waking
                        }
                    }
                    mood = m;
                }

                // Occasional grumpy fit while strolling — surfaces the angry face + a bubble.
                if (active && mood === "happy" && state === "walking" && now >= nextGrumpyAt) {
                    fumeUntil = now + rand(2.6, 4.4);
                    mood = "mad";
                    state = "fuming";
                    popBubble(madLines[Math.floor(Math.random() * madLines.length)], 5.5);
                    nextGrumpyAt = now + rand(40, 100);
                }

                advance(dt, now);

                if (bubbleText !== "" && now > bubbleUntil)
                    bubbleText = "";

                makePose(now);
            }

            function advance(dt: real, now: real): void {
                const minX = charHalf;
                const maxX = width - charHalf;
                switch (state) {
                case "walking":
                    if (mood === "sleepy") {
                        state = "sitting";
                        break;
                    }
                    walkClock += dt * strideHz(mood);
                    charX += facing * baseSpeed * speedFactor(mood) * dt;
                    if ((facing > 0 && charX >= maxX) || (facing < 0 && charX <= minX)) {
                        state = "turning";
                        turnStart = now;
                        turnFromFacing = facing;
                    } else if (now >= nextIdleAt) {
                        idleUntil = now + rand(idleLengthMin, idleLengthMax);
                        state = "idling";
                    }
                    break;
                case "turning":
                    if (now - turnStart >= turnDuration) {
                        facing = -turnFromFacing;
                        state = "walking";
                        scheduleIdle();
                    }
                    break;
                case "idling":
                    if (mood === "sleepy")
                        state = "sitting";
                    else if (now >= idleUntil) {
                        state = "walking";
                        scheduleIdle();
                    }
                    break;
                case "sitting":
                    if (mood !== "sleepy") {
                        state = "walking";
                        scheduleIdle();
                    }
                    break;
                case "fuming":
                    if (mood !== "mad") {
                        state = "walking";
                    } else if (now >= fumeUntil) {
                        if ((facing > 0 && charX >= maxX - 1) || (facing < 0 && charX <= minX + 1))
                            facing = -facing;
                        mood = "happy";
                        state = "walking";
                        scheduleIdle();
                    }
                    break;
                case "dragging":
                    break; // position is driven by the mouse handler
                case "falling":
                    vy -= gravity * dt;
                    if (vy < -terminalFall)
                        vy = -terminalFall;
                    airHeight += vy * dt;
                    charX = clampX(charX + tossVX * dt);
                    tossVX *= Math.exp(-2.5 * dt);
                    if (airHeight <= 0) {
                        airHeight = 0;
                        state = "landing";
                        landStart = now;
                    }
                    break;
                case "landing":
                    if (now - landStart >= landDuration) {
                        state = mood === "sleepy" ? "sitting" : "walking";
                        scheduleIdle();
                    }
                    break;
                }
                if (state !== "dragging") {
                    charX = clampX(charX);
                    pipY = state === "falling" ? groundY - airHeight : groundY;
                }
            }

            function makePose(now: real): void {
                pip.facing = facing;
                pip.sleeping = false;
                pip.bodyLift = 0;
                pip.bodySquash = 0;
                pip.rockDeg = 0;
                const breath = (Math.sin(now * 2 * Math.PI / 3.2) + 1) / 2;
                switch (state) {
                case "walking":
                    {
                        const raw = walkClock % 2;
                        pip.animSet = facing > 0 ? "walk-right" : "walk-left";
                        pip.frame = Math.min(9, Math.floor(raw * 5));
                        const f = walkClock % 1;
                        const arc = Math.sin(Math.PI * f) * Math.sin(Math.PI * f);
                        pip.bodyLift = arc * 2.5;
                        pip.bodySquash = 0.03 - 0.05 * arc;
                        pip.rockDeg = 1.5 * Math.cos(Math.PI * raw) * (facing > 0 ? 1 : -1);
                        break;
                    }
                case "turning":
                    {
                        const p = Math.min(1, Math.max(0, (now - turnStart) / turnDuration));
                        const pp = turnFromFacing > 0 ? p : 1 - p; // frames ordered right→front→left
                        pip.animSet = "turn";
                        pip.frame = Math.min(5, Math.max(0, Math.floor(pp * 6)));
                        pip.bodyLift = Math.sin(Math.PI * p) * 1.5;
                        pip.bodySquash = Math.sin(Math.PI * p) * 0.04;
                        break;
                    }
                case "idling":
                    pip.animSet = facing > 0 ? "idle-right" : "idle-left";
                    pip.frame = 0;
                    pip.bodySquash = breath * 0.035;
                    break;
                case "sitting":
                    pip.animSet = facing > 0 ? "idle-right" : "idle-left";
                    pip.frame = 0;
                    pip.bodySquash = 0.09 + breath * 0.025;
                    pip.rockDeg = facing > 0 ? 2 : -2;
                    pip.sleeping = mood === "sleepy";
                    break;
                case "fuming":
                    {
                        pip.animSet = "mad";
                        pip.frame = 8 + Math.floor(now / 0.12) % 4; // red-faced furious row
                        pip.bodyLift = Math.max(0, Math.sin(now * 2 * Math.PI * 5.5)) * 4.5;
                        break;
                    }
                case "dragging":
                    {
                        const t = now - dragStart;
                        if (t < 0.32) {
                            pip.animSet = "pickup"; // snatched off the ground
                            pip.frame = Math.min(3, Math.floor(t / 0.08));
                        } else {
                            const spd = Math.max(Math.abs(dragVX), Math.abs(dragVYWin) * 0.6);
                            pip.animSet = "air";
                            if (spd > 700)
                                pip.frame = Math.floor(now / 0.15) % 2 ? 5 : 2;
                            else
                            // distressed
                            if (spd > 250)
                                pip.frame = Math.floor(now / 0.2) % 2 ? 1 : 0;
                            else
                                // soft lean
                                pip.frame = [0, 10, 11, 10][Math.floor(now / 0.45) % 4]; // calm dangle
                        }
                        break;
                    }
                case "falling":
                    {
                        const sp = Math.max(0, -vy);
                        pip.animSet = "fall";
                        pip.frame = Math.min(7, Math.round(sp / terminalFall * 7));
                        break;
                    }
                case "landing":
                    {
                        const p = Math.min(1, (now - landStart) / landDuration);
                        pip.animSet = "fall";
                        pip.frame = p < 0.16 ? 8 : p < 0.34 ? 9 : p < 0.6 ? 10 : 11;
                        break;
                    }
                }
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

            FrameAnimation {
                running: true
                onTriggered: win.tick(frameTime)
            }

            Pip {
                id: pip

                x: win.charX
                y: win.pipY
            }

            Item {
                id: bubble

                readonly property real maxW: 240

                x: Math.max(6, Math.min(win.width - width - 6, win.charX - width / 2))
                y: win.pipY - 170 - height
                width: card.width
                height: card.height + 7
                visible: opacity > 0.01
                opacity: win.bubbleText !== "" ? 1 : 0

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
                        text: win.bubbleText
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

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: win.beginDrag(mouseX, mouseY)
                onReleased: win.endDrag()
                onPositionChanged: {
                    if (pressed)
                        win.dragTo(mouseX, mouseY);
                }
            }
        }
    }
}
