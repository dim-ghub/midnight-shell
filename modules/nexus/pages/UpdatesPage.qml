pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Updates")
    property var packages: []
    property string errorText: ""
    property bool checkedOnce: false

    function refresh(): void {
        if (checker.running)
            return;
        packages = [];
        errorText = "";
        checkedOnce = false;
        checker.running = true;
    }

    property ScrollBar pageScrollbar: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    Component.onCompleted: {
        root.flickable.ScrollBar.vertical = pageScrollbar;
        refresh();
    }

    property Process updateChecker: Process {
        id: checker

        command: ["python3", Quickshell.shellDir + "/assets/scripts/list_updates.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!Array.isArray(result.packages) || !Array.isArray(result.errors))
                        throw new Error("Invalid update preview");
                    root.packages = result.packages;
                    root.errorText = result.errors.join("\n");
                    root.checkedOnce = true;
                } catch (error) {
                    root.errorText = Tr.tr("Unable to read the update list.");
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.errorText = Tr.tr("Unable to check for updates. Try again.");
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cappedWidth
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: checker.running ? Tr.tr("Checking repository and AUR updates…")
                : root.errorText ? Tr.tr("Some update sources could not be checked.")
                : !root.checkedOnce ? Tr.tr("Check for available updates.")
                : root.packages.length === 0 ? Tr.tr("The system is up to date.")
                : Tr.trN("%n package available to update", "%n packages available to update", root.packages.length)
            wrapMode: Text.WordWrap
        }

        IconTextButton {
            text: checker.running ? Tr.tr("Checking…") : Tr.tr("Check for updates")
            icon: "refresh"
            enabled: !checker.running
            onClicked: root.refresh()
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Preview updates on Arch Linux using checkupdates. AUR packages are included when paru or yay is installed. This page does not install packages.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.errorText.length > 0
            text: root.errorText
            color: Colours.palette.m3error
            wrapMode: Text.WrapAnywhere
        }

        ListView {
            id: packageList

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(480, count * 72)
            visible: count > 0
            model: root.packages
            clip: true
            spacing: Tokens.spacing.extraSmall
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: StyledRect {
                required property var modelData

                width: packageList.width
                implicitHeight: packageRow.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer

                RowLayout {
                    id: packageRow

                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.medium * 2
                    spacing: Tokens.spacing.medium

                    IconImage {
                        implicitSize: 32
                        source: Quickshell.iconPath(modelData.icon || "package-x-generic", "package-x-generic")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            wrapMode: Text.WrapAnywhere
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.current + " → " + modelData.new
                            color: Colours.palette.m3outline
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    StyledText {
                        text: modelData.source === "AUR" ? "AUR" : Tr.tr("Repository")
                    }
                }
            }
        }
    }
}
