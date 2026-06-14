pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Sprite renderer for the Pip mascot. Its (0,0) is the FEET contact point:
// the engine places this item at (charX, groundY) and the sprite is drawn
// upward and centered from there, with squash/rock/lift about the feet — so
// alternating stride frames (which carry the leg action) stay glued to the
// ground. Pose inputs are set by the walk engine in ClaudeIndicator.qml.
Item {
    id: root

    // Pose inputs (driven by the engine)
    property string animSet: "idle-right" // walk-right|walk-left|turn|idle-right|idle-left|mad|fall|pickup|air
    property int frame: 0
    property real facing: 1
    property real bodyLift: 0 // points the body rises off the ground
    property real bodySquash: 0 // + squashes (wider/shorter), − stretches
    property real rockDeg: 0 // body sway about the feet
    property bool sleeping: false // dozing: show zzz

    readonly property real spriteSide: 200
    // Fraction of the sprite height (from top) where the feet rest — measured
    // per set so the feet stay on the ground line as frames alternate.
    readonly property real footFrac: {
        if (animSet === "idle-right" || animSet === "idle-left")
            return 0.934;
        if (animSet === "fall")
            return 0.875;
        return 0.873;
    }
    readonly property real footY: footFrac * spriteSide
    readonly property bool mad: animSet === "mad"
    // Clamp per set: animSet and frame are set in separate steps, so a stale
    // high frame index must never pair with a shorter set and request a
    // nonexistent file (e.g. walk-right-f10).
    readonly property int clampedFrame: {
        const counts = {
            "walk-right": 10,
            "walk-left": 10,
            "turn": 6,
            "mad": 12,
            "fall": 12,
            "pickup": 12,
            "air": 12
        };
        return Math.max(0, Math.min(frame, (counts[animSet] ?? 1) - 1));
    }
    readonly property string frameName: {
        switch (animSet) {
        case "walk-right":
            return `walk-right-f${clampedFrame}`;
        case "walk-left":
            return `walk-left-f${clampedFrame}`;
        case "turn":
            return `turn-${clampedFrame}`;
        case "idle-left":
            return "idle-left";
        case "mad":
            return `mad-${clampedFrame}`;
        case "fall":
            return `fall-${clampedFrame}`;
        case "pickup":
            return `pickup-${clampedFrame}`;
        case "air":
            return `air-${clampedFrame}`;
        default:
            return "idle-right";
        }
    }

    Image {
        id: img

        x: -root.spriteSide / 2
        y: -root.footY - root.bodyLift
        width: root.spriteSide
        height: root.spriteSide
        source: Quickshell.shellPath(`assets/pip/${root.frameName}.png`)
        smooth: true
        mipmap: true
        cache: true
        asynchronous: false
        fillMode: Image.PreserveAspectFit

        transform: [
            Scale {
                origin.x: root.spriteSide / 2
                origin.y: root.footY
                xScale: 1 + root.bodySquash
                yScale: 1 - root.bodySquash
            },
            Rotation {
                origin.x: root.spriteSide / 2
                origin.y: root.footY
                angle: root.rockDeg
            }
        ]
    }

    // Manga anger veins while fuming — two throbbing 💢 marks by the head.
    Repeater {
        model: root.mad ? 2 : 0

        Canvas {
            id: anger

            required property int index

            readonly property real big: index === 0 ? 1 : 0.75

            x: (index === 0 ? 47 : -46) - width / 2
            y: (-root.footY + root.spriteSide * 0.12) + (index === 0 ? 2 : 14) - height / 2
            width: 34
            height: 34
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                const r = 9 * big;
                ctx.strokeStyle = "#d93329";
                ctx.lineWidth = 2.6 * big;
                ctx.lineCap = "round";
                for (let i = 0; i < 4; i++) {
                    const a = i * Math.PI / 2 + Math.PI / 4;
                    const ix = c + Math.cos(a) * 2 * big;
                    const iy = c + Math.sin(a) * 2 * big;
                    const ox = c + Math.cos(a) * r;
                    const oy = c + Math.sin(a) * r;
                    const bend = a + Math.PI / 2;
                    const mx = (ix + ox) / 2 + Math.cos(bend) * 3.6 * big;
                    const my = (iy + oy) / 2 + Math.sin(bend) * 3.6 * big;
                    ctx.beginPath();
                    ctx.moveTo(ix, iy);
                    ctx.quadraticCurveTo(mx, my, ox, oy);
                    ctx.stroke();
                }
            }

            SequentialAnimation on scale {
                running: root.mad
                loops: Animation.Infinite

                NumberAnimation {
                    from: 0.82
                    to: 1.12
                    duration: 230
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    from: 1.12
                    to: 0.82
                    duration: 230
                    easing.type: Easing.InQuad
                }
            }
        }
    }

    // Floating "z z z" while dozing.
    Repeater {
        model: root.sleeping ? 3 : 0

        Text {
            id: zzz

            required property int index

            text: "z"
            color: "#3c2c26"
            font.pixelSize: 11 + index * 4
            font.bold: true
            x: 30 + index * 5
            y: -root.footY + root.spriteSide * 0.1

            SequentialAnimation on opacity {
                running: root.sleeping
                loops: Animation.Infinite

                PauseAnimation {
                    duration: zzz.index * 500
                }

                NumberAnimation {
                    from: 0
                    to: 0.85
                    duration: 700
                }

                NumberAnimation {
                    from: 0.85
                    to: 0
                    duration: 700
                }

                PauseAnimation {
                    duration: (2 - zzz.index) * 500
                }
            }

            SequentialAnimation on y {
                running: root.sleeping
                loops: Animation.Infinite

                PauseAnimation {
                    duration: zzz.index * 500
                }

                NumberAnimation {
                    from: -root.footY + root.spriteSide * 0.1
                    to: -root.footY + root.spriteSide * 0.1 - 26
                    duration: 1400
                    easing.type: Easing.OutQuad
                }

                PauseAnimation {
                    duration: (2 - zzz.index) * 500
                }
            }
        }
    }
}
