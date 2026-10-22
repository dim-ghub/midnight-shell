pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Audio")

    function addApp() {
        let appName = silenceAppInput.text.trim();
        if (appName !== "") {
            let list = Array.from(GlobalConfig.audio.sounds.disabledNotifApps);
            if (!list.includes(appName)) {
                list.push(appName);
                GlobalConfig.audio.sounds.disabledNotifApps = list;
                GlobalConfig.save();
            }
            silenceAppInput.text = "";
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Show hidden devices")
            checked: Audio.showHiddenDevices
            onToggled: Audio.showHiddenDevices = checked
        }

        // Output
        SliderRow {
            first: true
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            label: Tr.trCtx("Output", "audio output")
            valueLabel: Strings.percentOne(value)
            value: Audio.volume
            enabled: !Audio.muted
            onMoved: v => Audio.setVolume(v)
            onReleased: v => Audio.playEffectTick()
        }

        ToggleRow {
            text: Tr.trCtx("Muted", "audio output muted")
            checked: Audio.muted
            onToggled: Audio.setStreamMuted(Audio.sink, checked)
        }

        AudioDeviceList {
            nodes: Audio.sinks
            currentId: Audio.sink?.id ?? -1
            iconName: "speaker"
            placeholderIcon: "speaker"
            placeholderText: Tr.trCtx("No output devices", "no audio outputs")
            onSelected: node => Audio.setAudioSink(node)
        }

        // Input
        SliderRow {
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            first: true
            icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            label: Tr.trCtx("Input", "audio input")
            valueLabel: Strings.percentOne(value)
            value: Audio.sourceVolume
            enabled: !Audio.sourceMuted
            onMoved: v => Audio.setSourceVolume(v)
            onReleased: v => Audio.playEffectTick()
        }

        ToggleRow {
            text: Tr.trCtx("Muted", "audio input muted")
            checked: Audio.sourceMuted
            onToggled: Audio.setStreamMuted(Audio.source, checked)
        }

        AudioDeviceList {
            nodes: Audio.sources
            currentId: Audio.source?.id ?? -1
            iconName: "mic"
            placeholderIcon: "mic_off"
            placeholderText: Tr.trCtx("No input devices", "no audio inputs")
            onSelected: node => Audio.setAudioSource(node)
        }

        // Per-app volumes
        NavRow {
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            first: true
            last: true

            icon: "tune"
            text: Tr.tr("App volumes")
            subtext: Audio.streams.length === 0 ? Tr.tr("No apps playing audio") : Tr.trN("%n app playing audio", "%n apps playing audio", Audio.streams.length)
            onClicked: root.nState.openSubPage(1)
        }

        // Sound effects
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            text: qsTr("Sound effects")
            font: Tokens.font.body.small
            color: Colours.palette.m3primary
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Enable sound effects")
            checked: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.enabled = checked
        }

        SliderRow {
            Layout.fillWidth: true
            icon: "volume_up"
            label: qsTr("SFX Volume")
            valueLabel: Math.round(value * 100) + "%"
            value: GlobalConfig.audio.sounds.sfxVolume
            enabled: GlobalConfig.audio.sounds.enabled
            onMoved: v => GlobalConfig.audio.sounds.sfxVolume = v
            onReleased: v => Audio.playEffectTick()
        }

        SliderRow {
            Layout.fillWidth: true
            icon: "notifications"
            label: qsTr("Notification Volume")
            valueLabel: Math.round(value * 100) + "%"
            value: GlobalConfig.audio.sounds.notificationVolume
            enabled: GlobalConfig.audio.sounds.enabled
            onMoved: v => GlobalConfig.audio.sounds.notificationVolume = v
            onReleased: v => Audio.playNotification()
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Camera click")
            checked: GlobalConfig.audio.sounds.cameraClick
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.cameraClick = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Charging started")
            checked: GlobalConfig.audio.sounds.chargingStarted
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.chargingStarted = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Volume tick")
            checked: GlobalConfig.audio.sounds.effectTick
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.effectTick = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Screen lock")
            checked: GlobalConfig.audio.sounds.lock
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.lock = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Screen unlock")
            checked: GlobalConfig.audio.sounds.unlock
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.unlock = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Low battery")
            checked: GlobalConfig.audio.sounds.lowBattery
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.lowBattery = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: qsTr("Screen record")
            checked: GlobalConfig.audio.sounds.screenRecord
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.screenRecord = checked
        }

        // Notification Silencing
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            text: qsTr("Notification silencing")
            font: Tokens.font.body.small
            color: Colours.palette.m3primary
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.medium
            text: qsTr("Mute notification sounds for specific apps")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: silenceAppInput

                Layout.fillWidth: true
                onEditingFinished: root.addApp()
            }

            IconTextButton {
                text: qsTr("Add")
                icon: "add"
                onClicked: root.addApp()
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: GlobalConfig.audio.sounds.disabledNotifApps
                delegate: StyledRect {
                    required property string modelData
                    required property int index

                    width: implicitWidth
                    height: implicitHeight
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    radius: Tokens.rounding.large
                    implicitWidth: chipLayout.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: chipLayout.implicitHeight + Tokens.padding.extraSmall * 2

                    RowLayout {
                        id: chipLayout

                        x: Tokens.padding.medium
                        y: Tokens.padding.extraSmall
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            text: modelData
                        }

                        MaterialIcon {
                            text: "close"
                            font: Tokens.font.icon.small

                            StateLayer {
                                onClicked: {
                                    let list = Array.from(GlobalConfig.audio.sounds.disabledNotifApps);
                                    list.splice(index, 1);
                                    GlobalConfig.audio.sounds.disabledNotifApps = list;
                                    GlobalConfig.save();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
