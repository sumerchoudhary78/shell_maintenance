pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D
import qs.components

View3D {
    id: root

    property bool animating: true
    property real facing: 1 // 1 = walking right, -1 = walking left
    property color colour: "#D97757"
    property color eyeColour: "#221712"
    property real walkPhase: 0
    property real blink: 1

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
        running: root.animating
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

    Timer {
        // random hops and blinks so the walk doesn't look mechanical
        running: root.animating
        repeat: true
        interval: 3500 + Math.random() * 5000
        onTriggered: {
            if (Math.random() < 0.45)
                hopAnim.restart();
            else
                blinkAnim.restart();
            interval = 3500 + Math.random() * 5000;
        }
    }

    Node {
        id: clawd

        eulerRotation.y: root.facing * 24
        eulerRotation.z: Math.sin(root.walkPhase) * 2.5

        Behavior on eulerRotation.y {
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

            position.y: Math.sin(root.walkPhase * 2) * 4

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
        }

        Repeater3D {
            model: [-55, -20, 20, 55]

            Model {
                id: leg

                required property real modelData
                required property int index

                source: "#Cube"
                position: Qt.vector3d(modelData, -47.5 + (root.animating ? Math.max(0, Math.sin(root.walkPhase + (index % 2) * Math.PI)) * 12 : 0), 0)
                scale: Qt.vector3d(0.16, 0.25, 0.18)
                materials: [bodyMat]
            }
        }
    }
}
