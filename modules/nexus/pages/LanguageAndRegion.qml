import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Temperature units (there must be one for each value of the TemperatureUnit enum)
    readonly property list<MenuItem> tempItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: TemperatureUnit.Auto
        },
        MenuItem {
            text: Tr.tr("°C")
            value: TemperatureUnit.Celsius
        },
        MenuItem {
            text: Tr.tr("°F")
            value: TemperatureUnit.Fahrenheit
        },
        MenuItem {
            text: Tr.tr("K")
            value: TemperatureUnit.Kelvin
        }
    ]

    // Data size units (there must be one for each value of the DataUnit enum)
    readonly property list<MenuItem> dataItems: [
        MenuItem {
            text: Tr.tr("Binary (KiB, MiB)")
            value: DataUnit.Binary
        },
        MenuItem {
            text: Tr.tr("Decimal (KB, MB)")
            value: DataUnit.Decimal
        }
    ]

    // Clock formats (there must be one for each value of the ClockFormat enum)
    readonly property list<MenuItem> clockItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: ClockFormat.Auto
        },
        MenuItem {
            text: Tr.tr("12-hour")
            value: ClockFormat.TwelveHour
        },
        MenuItem {
            text: Tr.tr("24-hour")
            value: ClockFormat.TwentyFourHour
        }
    ]

    Component.onDestruction: LocationSearch.clear()

    title: Tr.tr("Language & region")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Language
        SectionHeader {
            first: true
            text: Tr.tr("Language")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("UI language")
            subtext: Tr.tr("The language used in the shell UI")
            active: menuItems.find(i => i.modelData === Tr.language) ?? autoLang
            onSelected: item => {
                Tr.language = item.modelData ?? ""; // qmllint disable missing-property
            }

            menuItems: [autoLang, ...langItems.instances]

            MenuItem {
                id: autoLang

                text: Tr.tr("Auto")
            }

            Variants {
                id: langItems

                model: Tr.supportedLanguages

                MenuItem {
                    required property string modelData

                    text: {
                        const locale = Qt.locale(modelData);
                        return locale.name === "C" ? modelData : locale.nativeLanguageName || locale.name;
                    }
                }
            }
        }

        // Weather
        SectionHeader {
            text: Tr.tr("Weather")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: locationSettings.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: locationSettings
                x: Tokens.padding.medium
                y: Tokens.padding.medium
                width: parent.width - Tokens.padding.medium * 2
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Current location") + ": " + (Weather.city || GlobalConfig.services.weatherLocation || Tr.tr("Automatic"))
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("This location is used for the weather forecast.")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.WordWrap
                }
                IconTextButton {
                    text: Tr.tr("Automatic location (IP)")
                    icon: "my_location"
                    onClicked: {
                        LocationSearch.clear();
                        Weather.useAutomaticLocation();
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    StyledTextField {
                        id: citySearch
                        Layout.fillWidth: true
                        placeholderText: Tr.tr("City name…")
                        onAccepted: LocationSearch.search(text)
                    }
                    IconTextButton {
                        text: LocationSearch.loading ? Tr.tr("Searching…") : Tr.tr("Search")
                        icon: "search"
                        enabled: !LocationSearch.loading
                        onClicked: LocationSearch.search(citySearch.text)
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: LocationSearch.errorText.length > 0
                    text: LocationSearch.errorText
                    color: Colours.palette.m3error
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: LocationSearch.results
                    delegate: ColumnLayout {
                        id: placeRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall
                        StyledText {
                            Layout.fillWidth: true
                            text: [placeRow.modelData.name, placeRow.modelData.admin1, placeRow.modelData.country].filter(Boolean).join(", ")
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                        }
                        IconTextButton {
                            text: GlobalConfig.services.weatherLocation === placeRow.modelData.latitude + "," + placeRow.modelData.longitude ? Tr.tr("Selected") : Tr.tr("Select this city")
                            icon: "location_on"
                            onClicked: Weather.setLocation(placeRow.modelData.latitude, placeRow.modelData.longitude, placeRow.modelData.name)
                        }
                    }
                }
            }
        }

        // Units
        SectionHeader {
            text: Tr.tr("Units")
        }

        SelectRow {
            first: true
            label: Tr.tr("Temperature")
            subtext: Tr.tr("Units for weather temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.weatherUnits)
            onSelected: item => GlobalConfig.services.weatherUnits = item.value
        }

        SelectRow {
            label: Tr.tr("System temperatures")
            subtext: Tr.tr("Units for CPU and GPU temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.sensorUnits)
            onSelected: item => GlobalConfig.services.sensorUnits = item.value
        }

        SelectRow {
            last: true
            label: Tr.tr("Data sizes")
            subtext: Tr.tr("Units for data sizes and network speeds")
            menuItems: root.dataItems
            active: root.dataItems.find(i => i.value === GlobalConfig.services.dataUnits)
            onSelected: item => GlobalConfig.services.dataUnits = item.value
        }

        // Time & date
        SectionHeader {
            text: Tr.tr("Time & date")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Clock format")
            subtext: Tr.tr("How times are shown across the shell")
            menuOnTop: true
            menuItems: root.clockItems
            active: root.clockItems.find(i => i.value === GlobalConfig.services.clockFormat)
            onSelected: item => GlobalConfig.services.clockFormat = item.value
        }
    }
}
