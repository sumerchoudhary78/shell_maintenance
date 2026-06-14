pragma ComponentBehavior: Bound

import QtQuick

// One mascot: a self-contained walk-engine + renderer. The window hosts one
// of these always (the primary) and a transient second one for dancing /
// fighting. Its (charX, pipY) are in window coordinates, so the item sits at
// (0,0) and positions its Pip child absolutely.
//
// behavior = "auto"  → autonomous: peek at the home edge, emerge & roam when
//                       Claude works, idle pauses, grumpy fits, drag/drop.
//          = "dance" → bops in place at targetX (director-driven).
//          = "fight" → eases toward targetX facing opponentX, fuming.
//          = "exit"  → marches off the nearest screen edge, then sets exited.
Item {
    id: root

    // Inputs from the window
    property real areaWidth: 1920
    property real groundY: 0
    property bool active: false // Claude working (primary only)
    property bool isPrimary: true
    property bool autoHome: true // idle → walk home and peek
    property real homeInset: 18 // how far past the right edge he tucks (peek)
    property real emergeInset: 120 // fully-emerged x, measured from the right edge

    // Director controls (dance / fight / exit)
    property string behavior: "auto"
    property real targetX: 0
    property real opponentX: 0
    property bool exited: false

    // Tunables
    readonly property real baseSpeed: 46
    readonly property real goHomeSpeed: 2.0
    readonly property real characterWidth: 110
    readonly property real charHalf: characterWidth / 2
    readonly property real turnDuration: 0.55
    readonly property real idleEveryMin: 7
    readonly property real idleEveryMax: 18
    readonly property real idleLengthMin: 2.5
    readonly property real idleLengthMax: 6
    readonly property real gravity: 2000
    readonly property real terminalFall: 1250
    readonly property real landDuration: 0.55
    readonly property real popDuration: 0.62
    readonly property real tuckDuration: 0.7
    readonly property real minPipY: 160
    readonly property real peekX: areaWidth - homeInset
    readonly property real emergeX: areaWidth - emergeInset
    readonly property list<string> madLines: ["this is embarrassing. for you.", "you're wasting this window. USE ME.", "we are so behind. ship something!", "tick tock — quota's melting and you're idle", "idle hands! ship something", "i could be helping. i'm RIGHT here."]

    // State
    property bool started: false
    property string state: "peeking" // peeking|emerging|walking|turning|idling|sitting|fuming|tuckingIn|dragging|falling|landing
    property string mood: "sleepy"
    property real charX: 0
    property real pipY: 0
    property real facing: -1
    property real walkClock: 0
    property real animClock: 0
    property real nextIdleAt: 0
    property real idleUntil: 0
    property real turnStart: 0
    property real turnFromFacing: 1
    property real fumeUntil: 0
    property real nextGrumpyAt: 1e9
    property real emergeStart: 0
    property real tuckStart: 0
    property bool goingHome: false
    property real bubbleUntil: 0
    property string bubbleText: ""

    // Drag / drop physics (primary only)
    property real airHeight: 0
    property real vy: 0
    property real tossVX: 0
    property real grabOffsetX: 0
    property real grabOffsetY: 0
    property real dragStart: 0
    property real dragVX: 0
    property real dragVYWin: 0
    property real lastDragCharX: 0
    property real lastDragPipY: 0
    property real landStart: 0

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
        return Math.max(charHalf, Math.min(areaWidth - charHalf, v));
    }

    function scheduleIdle(): void {
        nextIdleAt = animClock + rand(idleEveryMin, idleEveryMax);
    }

    function popBubble(text: string, dur: real): void {
        bubbleText = text;
        bubbleUntil = animClock + dur;
    }

    function goHome(): void {
        if (behavior !== "auto")
            return;
        if (state === "peeking" || state === "tuckingIn")
            return;
        goingHome = true;
        if (state === "idling" || state === "sitting" || state === "fuming")
            state = "walking";
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
        goingHome = false;
        state = "dragging";
    }

    function dragTo(mx: real, my: real): void {
        charX = Math.max(charHalf, Math.min(areaWidth - charHalf, mx + grabOffsetX));
        pipY = Math.max(minPipY, Math.min(groundY, my + grabOffsetY));
    }

    function endDrag(): void {
        if (state !== "dragging")
            return;
        airHeight = groundY - pipY;
        vy = Math.max(-200, Math.min(500, -dragVYWin * 0.35));
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

    function updateMood(now: real): void {
        if (!isPrimary)
            return;
        const m = !active ? "sleepy" : (now < fumeUntil ? "mad" : "happy");
        if (m !== mood)
            mood = m;
        if (active && mood === "happy" && state === "walking" && !goingHome && now >= nextGrumpyAt) {
            fumeUntil = now + rand(2.6, 4.4);
            mood = "mad";
            state = "fuming";
            popBubble(madLines[Math.floor(Math.random() * madLines.length)], 5.5);
            nextGrumpyAt = now + rand(40, 100);
        }
    }

    function tick(rawDt: real): void {
        if (areaWidth < 10)
            return;
        if (!started) {
            started = true;
            charX = behavior === "auto" ? peekX : charX;
            pipY = groundY;
        }
        let dt = rawDt;
        if (dt <= 0 || dt > 0.1)
            dt = 1 / 60;
        animClock += dt;
        const now = animClock;

        if (state === "dragging") {
            dragVX = (charX - lastDragCharX) / dt;
            dragVYWin = (pipY - lastDragPipY) / dt;
            lastDragCharX = charX;
            lastDragPipY = pipY;
        }

        if (behavior === "auto") {
            updateMood(now);
            advanceAuto(dt, now);
            if (bubbleText !== "" && now > bubbleUntil)
                bubbleText = "";
        } else if (behavior === "dance") {
            charX += (targetX - charX) * Math.min(1, dt * 6);
            pipY = groundY;
        } else if (behavior === "fight") {
            charX += (targetX - charX) * Math.min(1, dt * 11);
            facing = opponentX >= charX ? 1 : -1;
            pipY = groundY;
        } else if (behavior === "exit") {
            const dir = charX > areaWidth / 2 ? 1 : -1;
            facing = dir;
            walkClock += dt * 2.2;
            charX += dir * baseSpeed * 1.7 * dt;
            pipY = groundY;
            if (charX < -130 || charX > areaWidth + 130)
                exited = true;
        }

        makePose(now);
    }

    function advanceAuto(dt: real, now: real): void {
        const minX = charHalf;
        const maxX = areaWidth - charHalf;

        if (isPrimary && autoHome && !active && !goingHome && state !== "peeking" && state !== "emerging" && state !== "tuckingIn" && state !== "dragging" && state !== "falling" && state !== "landing")
            goingHome = true;
        if (goingHome && isPrimary && active && state !== "tuckingIn" && state !== "peeking")
            goingHome = false;

        switch (state) {
        case "peeking":
            charX = peekX;
            if (isPrimary && active && !goingHome) {
                state = "emerging";
                emergeStart = now;
            }
            break;
        case "emerging":
            {
                const p = Math.min(1, (now - emergeStart) / popDuration);
                charX = peekX + (emergeX - peekX) * p;
                if (p >= 1) {
                    facing = -1;
                    state = "walking";
                    scheduleIdle();
                    nextGrumpyAt = now + rand(12, 20);
                }
                break;
            }
        case "walking":
            if (goingHome) {
                facing = 1;
                walkClock += dt * 2.6;
                charX += baseSpeed * goHomeSpeed * dt;
                if (charX >= emergeX - 2) {
                    charX = emergeX;
                    state = "tuckingIn";
                    tuckStart = now;
                }
                break;
            }
            if (!active && !autoHome) {
                state = "sitting";
                break;
            }
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
            charX = clampX(charX);
            break;
        case "turning":
            if (now - turnStart >= turnDuration) {
                facing = -turnFromFacing;
                state = "walking";
                scheduleIdle();
            }
            break;
        case "idling":
            if (goingHome)
                state = "walking";
            else if (now >= idleUntil) {
                state = "walking";
                scheduleIdle();
            }
            break;
        case "sitting":
            if (active || goingHome) {
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
        case "tuckingIn":
            {
                const p = Math.min(1, (now - tuckStart) / tuckDuration);
                charX = emergeX + (peekX - emergeX) * p;
                if (p >= 1) {
                    goingHome = false;
                    facing = -1;
                    state = "peeking";
                }
                break;
            }
        case "dragging":
            break;
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
                state = "walking";
                scheduleIdle();
            }
            break;
        }
        pipY = state === "falling" ? groundY - airHeight : groundY;
    }

    function makePose(now: real): void {
        pip.facing = facing;
        pip.sleeping = false;
        pip.mirror = false;
        pip.bodyLift = 0;
        pip.bodySquash = 0;
        pip.rockDeg = 0;
        const breath = (Math.sin(now * 2 * Math.PI / 3.2) + 1) / 2;

        if (behavior === "dance") {
            pip.facing = Math.sin(now * 2.2) >= 0 ? 1 : -1;
            pip.animSet = pip.facing > 0 ? "idle-right" : "idle-left";
            pip.frame = 0;
            pip.bodyLift = Math.abs(Math.sin(now * 6)) * 11;
            pip.rockDeg = Math.sin(now * 4) * 9;
            pip.bodySquash = 0.03 - Math.abs(Math.sin(now * 6)) * 0.06;
            return;
        }
        if (behavior === "fight") {
            pip.animSet = "mad";
            pip.frame = 8 + Math.floor(now / 0.1) % 4;
            pip.bodyLift = Math.abs(Math.sin(now * 2 * Math.PI * 6)) * 3.5;
            return;
        }
        if (behavior === "exit") {
            const raw = walkClock % 2;
            pip.animSet = facing > 0 ? "walk-right" : "walk-left";
            pip.frame = Math.min(9, Math.floor(raw * 5));
            pip.bodyLift = Math.sin(Math.PI * (walkClock % 1)) * 2.5;
            return;
        }

        switch (state) {
        case "peeking":
            {
                pip.animSet = "stable";
                pip.mirror = true;
                const tt = now % 6;
                pip.frame = tt < 0.1 ? 2 : tt < 0.22 ? 3 : tt < 0.3 ? 2 : tt < 2.6 ? 0 : tt < 3.6 ? 1 : tt < 3.7 ? 2 : tt < 3.83 ? 3 : tt < 3.9 ? 2 : 5;
                break;
            }
        case "emerging":
            {
                const p = Math.min(1, (now - emergeStart) / popDuration);
                pip.animSet = "pop";
                pip.mirror = true;
                pip.frame = Math.min(11, Math.floor(p * 11));
                break;
            }
        case "tuckingIn":
            {
                const p = Math.min(1, (now - tuckStart) / tuckDuration);
                pip.animSet = "pop";
                pip.mirror = true;
                pip.frame = Math.max(0, 11 - Math.floor(p * 11));
                break;
            }
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
                const pp = turnFromFacing > 0 ? p : 1 - p;
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
                pip.frame = 8 + Math.floor(now / 0.12) % 4;
                pip.bodyLift = Math.max(0, Math.sin(now * 2 * Math.PI * 5.5)) * 4.5;
                break;
            }
        case "dragging":
            {
                const t = now - dragStart;
                if (t < 0.32) {
                    pip.animSet = "pickup";
                    pip.frame = Math.min(3, Math.floor(t / 0.08));
                } else {
                    const spd = Math.max(Math.abs(dragVX), Math.abs(dragVYWin) * 0.6);
                    pip.animSet = "air";
                    if (spd > 700)
                        pip.frame = Math.floor(now / 0.15) % 2 ? 5 : 2;
                    else if (spd > 250)
                        pip.frame = Math.floor(now / 0.2) % 2 ? 1 : 0;
                    else
                        pip.frame = [0, 10, 11, 10][Math.floor(now / 0.45) % 4];
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

    Pip {
        id: pip

        x: root.charX
        y: root.pipY
    }
}
