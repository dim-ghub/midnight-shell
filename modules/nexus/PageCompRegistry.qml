pragma Singleton

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps
import qs.modules.nexus.pages.audio
import qs.modules.nexus.pages.bluetooth
import qs.modules.nexus.pages.network
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.services
import qs.modules.nexus.pages.wallandstyle
import qs.modules.nexus.pages.panels.taskbar
import qs.modules.nexus.pages.background
import qs.modules.nexus.pages.tokens
import qs.modules.nexus.pages.hyprland

QtObject {
    id: root

    readonly property list<Component> pageComps: [
        // Appearance
        Component {
            // Wallpaper & style
            StackPage {
                Component {
                    WallpaperAndStyle {}
                }
                Component {
                    WallpaperSelect {}
                }
                Component {
                    WallpaperCategory {}
                }
                Component {
                    ColourSelect {}
                }
                Component {
                    WallhavenPage {}
                }
                Component {
                    WallpaperEnginePage {}
                }
            }
        },
        Component {
            // Background elements
            StackPage {
                Component {
                    BackgroundPage {}
                }
                Component {
                    DesktopClockPage {}
                }
                Component {
                    DesktopLyricsPage {}
                }
                Component {
                    VisualiserPage {}
                }
                Component {
                    ShimejiPage {}
                }
            }
        },
        Component {
            // Shell Tokens
            StackPage {
                Component {
                    TokensPage {}
                }
                Component {
                    RoundingSpacingPage {}
                }
                Component {
                    FontSizesPage {}
                }
                Component {
                    BarDashboardPage {}
                }
                Component {
                    WindowLockPage {}
                }
                Component {
                    ShellElementsPage {}
                }
            }
        },

        // Connectivity
        Component {
            // Network
            StackPage {
                Component {
                    NetworkPage {}
                }
                Component {
                    EthernetDetailPage {}
                }
                Component {
                    AddNetworkPage {}
                }
                Component {
                    NetworkDetailPage {}
                }
                Component {
                    AddVpnPage {}
                }
                Component {
                    AllNetworksPage {}
                }
                Component {
                    SavedNetworksPage {}
                }
            }
        },
        Component {
            // Bluetooth
            StackPage {
                Component {
                    BluetoothPage {}
                }
                Component {
                    BtDeviceInfo {}
                }
                Component {
                    BluetoothPairing {}
                }
            }
        },
        Component {
            // Audio
            StackPage {
                Component {
                    AudioPage {}
                }
                Component {
                    AppVolumes {}
                }
            }
        },

        // System
        Component {
            StackPage {
                Component {
                    UpdatesPage {}
                }
            }
        },
        Component {
            PlaceholderComp {}
        },

        // Shell
        Component {
            // Panels
            StackPage {
                Component {
                    PanelsPage {}
                }
                Component {
                    DashboardPanel {}
                }
                Component {
                    TaskbarPanel {}
                }
                Component {
                    LauncherPanel {}
                }
                Component {
                    SidebarPanel {}
                }
                Component {
                    UtilitiesPanel {}
                }

                // Taskbar component sub-pages
                Component {
                    BarComponents {}
                }
                Component {
                    BarWorkspaces {}
                }
                Component {
                    BarActiveWindow {}
                }
                Component {
                    BarTray {}
                }
                Component {
                    BarStatusIcons {}
                }
                Component {
                    BarClock {}
                }
                Component {
                    BarDock {}
                }
                Component {
                    BarGithub {}
                }
                Component {
                    BarSpotify {}
                }
            }
        },
        Component {
            // Apps
            StackPage {
                Component {
                    AppsPage {}
                }
                Component {
                    AllApps {}
                }
                Component {
                    AppInfo {}
                }
            }
        },
        Component {
            // Hyprland
            StackPage {
                Component {
                    HyprlandPage {}
                }
                Component {
                    HyprVariablesPage {}
                }
                Component {
                    HyprKeybindsPage {}
                }
                Component {
                    UserConfigPage {}
                }
            }
        },
        Component {
            // Services
            StackPage {
                Component {
                    ServicesPage {}
                }
                Component {
                    NotificationsPage {}
                }
                Component {
                    GameModePage {}
                }
                Component {
                    GameModeTargetsPage {}
                }
                Component {
                    ArpcPage {}
                }
                Component {
                    PipPage {}
                }
                Component {
                    QuickSharePage {}
                }
            }
        },
        Component {
            // Language & region
            StackPage {
                Component {
                    LanguageAndRegion {}
                }
            }
        },


        // About
        Component {
            StackPage {
                Component {
                    AboutPage {}
                }
            }
        }
    ]

    readonly property Component placeholderComp: Component {
        PlaceholderComp {}
    }

    component PlaceholderComp: Item {
        property NexusState nState // To avoid the warning from non-existent property

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.padding.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "handyman"
                color: Colours.palette.m3outlineVariant
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("Page under construction")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.title.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("This page will be available in a future update.")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.body.large
            }
        }
    }
}
