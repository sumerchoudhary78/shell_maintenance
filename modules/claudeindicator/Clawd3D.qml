pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D
import qs.components

View3D {
    id: root

    property bool animating: true // allow timers/animations at all
    property bool walking: true // leg/arm cycle, waddle and bob
    property real facing: 1 // 1 = walking right, -1 = walking left
    property color colour: "#D97757"
    property color eyeColour: "#221712"
    property real walkPhase: 0
    property real blink: 1
    property real lookYaw: 0
    property real spinYaw: 0
    property real armWave: 0

    function hop(): void {
        hopAnim.restart();
    }

    function lookAround(): void {
        lookAnim.restart();
    }

    function wave(): void {
        waveAnim.restart();
    }

    function spin(): void {
        spinAnim.restart();
    }

    environment: SceneEnvironment {
        backgroundMode: SceneEnvironment.Transparent
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }

    PerspectiveCamera {
        position: Qt.vector3d(0, -5, 150)
    }

    DirectionalLight {
        eulerRotation: Qt.vector3d(-35, -25, 0)
        brightness: 1.6
    }

    DirectionalLight {
        eulerRotation: Qt.vector3d(30, 155, 0)
        brightness: 0.7
    }

    NumberAnimation on walkPhase {
        running: root.animating && root.walking
        loops: Animation.Infinite
        from: 0
        to: 6.2832
        duration: 550
    }

    SequentialAnimation {
        id: hopAnim

        NumberAnimation {
            target: clawd
            property: "position.y"
            to: 24
            duration: 180
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: clawd
            property: "position.y"
            to: 0
            duration: 220
            easing.type: Easing.InQuad
        }
    }

    SequentialAnimation {
        id: blinkAnim

        NumberAnimation {
            target: root
            property: "blink"
            to: 0.12
            duration: 70
        }

        NumberAnimation {
            target: root
            property: "blink"
            to: 1
            duration: 90
        }
    }

    SequentialAnimation {
        id: lookAnim

        NumberAnimation {
            target: root
            property: "lookYaw"
            to: -38
            duration: 300
            easing.type: Easing.InOutQuad
        }

        PauseAnimation {
            duration: 400
        }

        NumberAnimation {
            target: root
            property: "lookYaw"
            to: 38
            duration: 450
            easing.type: Easing.InOutQuad
        }

        PauseAnimation {
            duration: 400
        }

        NumberAnimation {
            target: root
            property: "lookYaw"
            to: 0
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    SequentialAnimation {
        id: waveAnim

        NumberAnimation {
            target: root
            property: "armWave"
            to: 1
            duration: 220
            easing.type: Easing.OutBack
        }

        NumberAnimation {
            target: root
            property: "armWave"
            to: 0.82
            duration: 140
        }

        NumberAnimation {
            target: root
            property: "armWave"
            to: 1
            duration: 140
        }

        NumberAnimation {
            target: root
            property: "armWave"
            to: 0.82
            duration: 140
        }

        NumberAnimation {
            target: root
            property: "armWave"
            to: 1
            duration: 140
        }

        NumberAnimation {
            target: root
            property: "armWave"
            to: 0
            duration: 250
            easing.type: Easing.InQuad
        }
    }

    SequentialAnimation {
        id: spinAnim

        NumberAnimation {
            target: root
            property: "spinYaw"
            to: 360
            duration: 700
            easing.type: Easing.InOutCubic
        }

        ScriptAction {
            script: root.spinYaw = 0
        }
    }

    Timer {
        // random blinks (and the odd hop) so he doesn't look mechanical
        running: root.animating
        repeat: true
        interval: 3500 + Math.random() * 5000
        onTriggered: {
            if (Math.random() < 0.25)
                hopAnim.restart();
            else
                blinkAnim.restart();
            interval = 3500 + Math.random() * 5000;
        }
    }

    Node {
        id: clawd

        property real facingYaw: root.facing * 24

        eulerRotation.y: facingYaw + root.lookYaw + root.spinYaw
        eulerRotation.z: root.walking ? Math.sin(root.walkPhase) * 2.5 : 0

        Behavior on facingYaw {
            Anim {
                type: Anim.Emphasized
            }
        }

        PrincipledMaterial {
            id: bodyMat

            baseColor: root.colour
            roughness: 0.6
        }

        PrincipledMaterial {
            id: eyeMat

            baseColor: root.eyeColour
            roughness: 0.5
        }

        Node {
            id: body

            position.y: root.walking ? Math.sin(root.walkPhase * 2) * 4 : 0

            Model {
                source: "#Cube"
                scale: Qt.vector3d(1.4, 0.7, 0.5)
                materials: [bodyMat]
            }

            Model {
                // narrower top cap for the notched pixel-art corners
                source: "#Cube"
                position: Qt.vector3d(0, 40, 0)
                scale: Qt.vector3d(1.2, 0.1, 0.5)
                materials: [bodyMat]
            }

            Repeater3D {
                model: [-25, 25]

                Model {
                    required property real modelData

                    source: "#Cube"
                    position: Qt.vector3d(modelData, 12, 28)
                    scale: Qt.vector3d(0.16, 0.18 * root.blink, 0.06)
                    materials: [eyeMat]
                }
            }

            Repeater3D {
                // arms hang from the shoulders and swing opposite to the legs
                model: [-1, 1]

                Node {
                    id: shoulder

                    required property real modelData

                    position: Qt.vector3d(modelData * 77, 18, 0)
                    eulerRotation.x: root.walking ? Math.sin(root.walkPhase + (modelData < 0 ? Math.PI : 0)) * 18 : 0
                    eulerRotation.z: modelData > 0 ? root.armWave * 135 : 0

                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, -16, 0)
                        scale: Qt.vector3d(0.13, 0.32, 0.16)
                        materials: [bodyMat]
                    }
                }
            }
        }

        Repeater3D {
            model: [-22, 22]

            Model {
                id: leg

                required property real modelData
                required property int index

                source: "#Cube"
                position: Qt.vector3d(modelData, -47.5 + (root.walking ? Math.max(0, Math.sin(root.walkPhase + (index % 2) * Math.PI)) * 12 : 0), 0)
                scale: Qt.vector3d(0.18, 0.25, 0.18)
                materials: [bodyMat]
            }
        }
    }
}
