pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.services
import qs.utils

Item {
    id: root

    property string source: Wallpapers.current
    property Item current
    property bool completed

    onSourceChanged: {
        if (!source)
            current = null;
        else
            current = imgComp.createObject(this, {
                path: source
            });
    }

    Component.onCompleted: {
        if (source)
            Qt.callLater(() => {
                current = imgComp.createObject(this, {
                    path: source
                });
                completed = true;
            });
    }

    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image/video files")
                            filters: Images.validWallpaperExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    Component {
        id: imgComp

        Item {
            id: slot

            required property string path
            readonly property bool ready: loader.item?.ready ?? false // qmllint disable missing-property

            anchors.fill: parent

            opacity: 0

            onReadyChanged: {
                if (ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Loader {
                id: loader

                anchors.fill: parent
                asynchronous: true

                Component.onCompleted: {
                    if (Images.isValidVideoByName(slot.path))
                        setSource("WallpaperVideo.qml", {
                            path: slot.path
                        });
                    else if (Images.isAnimatedImageByName(slot.path))
                        setSource("WallpaperAnimated.qml", {
                            path: slot.path
                        });
                    else
                        setSource("WallpaperImage.qml", {
                            path: slot.path
                        });
                }

                // QtMultimedia may be missing; fall back to a static extracted frame
                onStatusChanged: {
                    if (status === Loader.Error && Images.isValidVideoByName(slot.path)) {
                        console.warn("Wallpaper: failed to load video player (is QtMultimedia installed?), falling back to a static frame");
                        setSource("WallpaperImage.qml", {
                            path: Wallpapers.videoFramePath(slot.path)
                        });
                    }
                }
            }

            Timer {
                running: root.current !== slot && root.current?.ready
                interval: anim.duration
                onTriggered: slot.destroy()
            }
        }
    }
}
