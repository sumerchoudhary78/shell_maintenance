pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D

View3D {
    id: root

    property bool spinning: true
    property color colour: "#D97757"

    // Irregular sunburst rays approximating the Claude logo, in the XY plane
    readonly property list<var> rays: [
        {
            angle: 90,
            length: 88,
            width: 16
        },
        {
            angle: 62,
            length: 72,
            width: 15
        },
        {
            angle: 32,
            length: 84,
            width: 16
        },
        {
            angle: 8,
            length: 68,
            width: 15
        },
        {
            angle: -18,
            length: 86,
            width: 16
        },
        {
            angle: -48,
            length: 70,
            width: 15
        },
        {
            angle: -78,
            length: 88,
            width: 16
        },
        {
            angle: -108,
            length: 74,
            width: 15
        },
        {
            angle: -140,
            length: 84,
            width: 16
        },
        {
            angle: -168,
            length: 68,
            width: 15
        },
        {
            angle: 162,
            length: 86,
            width: 16
        },
        {
            angle: 124,
            length: 74,
            width: 15
        }
    ]

    environment: SceneEnvironment {
        backgroundMode: SceneEnvironment.Transparent
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }

    PerspectiveCamera {
        position: Qt.vector3d(0, 0, 290)
    }

    DirectionalLight {
        eulerRotation: Qt.vector3d(-35, -25, 0)
        brightness: 1.6
    }

    DirectionalLight {
        eulerRotation: Qt.vector3d(30, 155, 0)
        brightness: 0.7
    }

    Node {
        id: logo

        property real pulse: 1

        scale: Qt.vector3d(pulse, pulse, pulse)

        PrincipledMaterial {
            id: rayMaterial

            baseColor: root.colour
            roughness: 0.4
            metalness: 0.1
        }

        Repeater3D {
            model: root.rays

            Model {
                id: ray

                required property var modelData
                readonly property real rad: modelData.angle * Math.PI / 180

                source: "#Cube"
                position: Qt.vector3d(Math.cos(rad) * (10 + modelData.length / 2), Math.sin(rad) * (10 + modelData.length / 2), 0)
                eulerRotation.z: modelData.angle
                scale: Qt.vector3d(modelData.length / 100, modelData.width / 100, 0.15)
                materials: [rayMaterial]
            }
        }

        NumberAnimation on eulerRotation.y {
            running: root.spinning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 3200
        }

        SequentialAnimation on eulerRotation.x {
            running: root.spinning
            loops: Animation.Infinite

            NumberAnimation {
                from: -14
                to: 14
                duration: 2100
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                from: 14
                to: -14
                duration: 2100
                easing.type: Easing.InOutSine
            }
        }

        SequentialAnimation on pulse {
            running: root.spinning
            loops: Animation.Infinite

            NumberAnimation {
                from: 1
                to: 1.07
                duration: 1300
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                from: 1.07
                to: 1
                duration: 1300
                easing.type: Easing.InOutSine
            }
        }
    }
}
