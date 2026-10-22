pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property PopoutState popouts

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal && popouts.currentSection === "end"

    implicitWidth: Math.max(300, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium

    ButtonGroup { id: sinks }
    ButtonGroup { id: sources }

    IconTextButton {
        Layout.fillWidth: true
        text: Audio.showHiddenDevices ? Tr.tr("Stop showing hidden devices") : Tr.tr("Show hidden devices")
        icon: Audio.showHiddenDevices ? "visibility_off" : "visibility"
        onClicked: Audio.showHiddenDevices = !Audio.showHiddenDevices
    }

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        Layout.leftMargin: Tokens.padding.small
        text: qsTr("Audio")
        font.weight: 500
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: outputLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: outputLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: outputLayout

            width: parent.width - Tokens.padding.medium * 2
            x: Tokens.padding.medium
            y: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            StyledText {
                text: qsTr("Output device")
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            }

            Repeater {
                model: Audio.sinks.filter(node => Audio.showHiddenDevices || !Audio.isDeviceHidden(node))

                RowLayout {
                    id: outputControl
                    required property PwNode modelData
                    Layout.fillWidth: true
                    StyledRadioButton {
                        Layout.fillWidth: true
                        ButtonGroup.group: sinks
                        checked: Audio.sink?.id === outputControl.modelData.id
                        onClicked: Audio.setAudioSink(outputControl.modelData)
                        text: outputControl.modelData.description
                    }
                    IconTextButton {
                        enabled: !!outputControl.modelData.name
                        text: Audio.isDeviceHidden(outputControl.modelData) ? Tr.tr("Show") : Tr.tr("Hide")
                        icon: Audio.isDeviceHidden(outputControl.modelData) ? "visibility" : "visibility_off"
                        onClicked: Audio.toggleDeviceHidden(outputControl.modelData)
                    }
                }
            }
        }
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: inputLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: inputLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: inputLayout

            width: parent.width - Tokens.padding.medium * 2
            x: Tokens.padding.medium
            y: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            StyledText {
                text: qsTr("Input device")
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            }

            Repeater {
                model: Audio.sources.filter(node => Audio.showHiddenDevices || !Audio.isDeviceHidden(node))

                RowLayout {
                    id: inputControl
                    required property PwNode modelData
                    Layout.fillWidth: true
                    StyledRadioButton {
                        Layout.fillWidth: true
                        ButtonGroup.group: sources
                        checked: Audio.source?.id === inputControl.modelData.id
                        onClicked: Audio.setAudioSource(inputControl.modelData)
                        text: inputControl.modelData.description
                    }
                    IconTextButton {
                        enabled: !!inputControl.modelData.name
                        text: Audio.isDeviceHidden(inputControl.modelData) ? Tr.tr("Show") : Tr.tr("Hide")
                        icon: Audio.isDeviceHidden(inputControl.modelData) ? "visibility" : "visibility_off"
                        onClicked: Audio.toggleDeviceHidden(inputControl.modelData)
                    }
                }
            }
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.medium
        text: Audio.muted ? qsTr("Volume (Muted)") : qsTr("Volume (%1%)").arg(Math.round(Audio.volume * 100))
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    CustomMouseArea {
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 3

        onWheel: event => {
            if (event.angleDelta.y > 0)
                Audio.incrementVolume();
            else if (event.angleDelta.y < 0)
                Audio.decrementVolume();
        }

        StyledSlider {
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: parent.implicitHeight

            value: Audio.volume
            onInteraction: v => Audio.setVolume(v)
            onReleased: v => Audio.playEffectTick()
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small
        text: qsTr("Open settings")
        icon: "settings"

        onClicked: root.popouts.detachRequested("audio")
    }
}
