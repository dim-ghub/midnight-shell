pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
import Caelestia.State
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    readonly property bool shouldBeActive: Config.background.visualiser.enabled && !(RuntimeState.gameMode && GlobalConfig.utilities.gameMode.disableVisualizer) && (!Config.background.visualiser.autoHide || (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true))
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    readonly property int barExclusiveZone: Visibilities.bars.get(root.screen.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
    readonly property real visualiserSpacing: Tokens.spacing.small * Config.background.visualiser.spacing
    readonly property real fallbackMargin: Tokens.padding.large + Tokens.spacing.small

    readonly property bool rendererGpu: Config.background.visualiser.renderer !== "cpu"

    opacity: shouldBeActive ? 1 : 0

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.opacity > 0 && Config.background.visualiser.blur

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        layer.enabled: root.opacity > 0 && Config.background.visualiser.blur

        Loader {
            asynchronous: true
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.opacity > 0

            sourceComponent: Item {
                ServiceRef {
                    service: Audio.cava
                }

                VisualiserBars {
                    id: bars

                    readonly property real baseMargin: root.barExclusiveZone + root.visualiserSpacing

                    anchors.fill: parent
                    anchors.margins: Config.border.thickness
                    anchors.leftMargin: Config.bar.position === "left" ? (root.barExclusiveZone + root.fallbackMargin) : root.fallbackMargin
                    anchors.rightMargin: Config.bar.position === "right" ? (root.barExclusiveZone + root.fallbackMargin) : root.fallbackMargin
                    anchors.topMargin: Config.bar.position === "top" ? root.barExclusiveZone : Config.border.thickness
                    anchors.bottomMargin: Config.bar.position === "bottom" ? root.barExclusiveZone : (GlobalConfig.appearance.islands ? 0 : Config.border.thickness)

                    visible: Config.background.visualiser.renderer === "cpu"

                    values: Audio.cava.values
                    primaryColor: Qt.alpha(Colours.palette.m3primary, 0.7)
                    secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)
                    rounding: Tokens.rounding.medium * Config.background.visualiser.rounding
                    spacing: Tokens.spacing.extraSmall * Config.background.visualiser.spacing
                    animationDuration: Tokens.anim.durations.expressiveDefaultEffects

                    Behavior on anchors.leftMargin {
                        Anim {}
                    }
                    Behavior on anchors.rightMargin {
                        Anim {}
                    }
                    Behavior on anchors.topMargin {
                        Anim {}
                    }
                    Behavior on anchors.bottomMargin {
                        Anim {}
                    }
                }

                Canvas {
                    id: dataCanvas

                    visible: false
                    width: Math.max(1, bars.displayValues.length)
                    height: 1

                    renderTarget: Canvas.FramebufferObject
                    renderStrategy: Canvas.Cooperative

                    onPaint: {
                        var ctx = getContext("2d");
                        var vals = bars.displayValues;
                        var n = vals.length;
                        for (let i = 0; i < n; i++) {
                            const b = vals[i];
                            const q = b <= 0 ? 0 : b >= 1 ? 65025 : Math.round(b * 65025);
                            ctx.fillStyle = Qt.rgba((q >> 8) / 255, (q & 255) / 255, 0, 1);
                            ctx.fillRect(i, 0, 1, 1);
                        }
                        dataTexSource.scheduleUpdate();
                    }

                    Component.onCompleted: requestPaint()
                }

                ShaderEffectSource {
                    id: dataTexSource

                    sourceItem: dataCanvas
                    hideSource: true
                    smooth: false
                    live: false
                }

                ShaderEffect {
                    id: gpuVisualiser

                    visible: Config.background.visualiser.renderer !== "cpu"
                    anchors.fill: bars

                    property variant dataTex: dataTexSource
                    property real itemWidth: width
                    property real itemHeight: height
                    property int barCount: bars.displayValues.length
                    property real rounding: bars.rounding
                    property real spacing: bars.spacing
                    property color primaryColor: bars.primaryColor
                    property color secondaryColor: bars.secondaryColor
                    property real dpr: root.screen.devicePixelRatio

                    fragmentShader: "qrc:/shaders/visualiser.frag.qsb"
                }

                // Keep decorative animation at 30 fps even on high-refresh displays.
                Timer {
                    property ElapsedTimer frameClock: ElapsedTimer {}
                    interval: 33
                    repeat: true
                    running: root.opacity > 0 && !bars.settled
                    onRunningChanged: frameClock.restart()
                    onTriggered: {
                        bars.advance(Math.min(0.1, frameClock.restart()));
                        if (root.rendererGpu) {
                            dataCanvas.requestPaint();
                        }
                    }
                }
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
