import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property Props props
    required property ScreenState screenState

    property var popouts
    property var utilities
    property bool sidebarStreaming: false

    readonly property bool isBarHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property bool showPopoutSeparator: isBarHorizontal && root.screenState.sidebar && popouts && popouts.hasCurrent && popouts.currentName !== "dockhover" && popouts.currentName !== "dockcontext" && popouts.currentName !== "activewindow" && popouts.currentName !== "github"

    property string activeTab: "notifications"

    readonly property bool aiAvailable: GlobalConfig.ai.enableOllama || GlobalConfig.ai.enableOpenRouter === true || GlobalConfig.ai.enableOpenClaw === true

    Connections {
        target: GlobalConfig.ai
        function onEnableOllamaChanged() { checkTabs(); }
        function onEnableOpenRouterChanged() { checkTabs(); }
        function onEnableOpenClawChanged() { checkTabs(); }
    }

    Connections {
        target: GlobalConfig.sidebar
        function onShowNewsChanged() { checkTabs(); }
    }

    Connections {
        target: root.screenState
        function onSidebarChanged() {
            if (root.screenState.sidebar) {
                root.activeTab = Visibilities.initialSidebarTab;
                checkTabs();
            }
        }
    }

    function checkTabs() {
        if (!root.aiAvailable) {
            if (root.activeTab === "ai") {
                root.activeTab = "notifications";
            }
        }
        if (GlobalConfig.sidebar.showNews === false) {
            if (root.activeTab === "news") {
                root.activeTab = "notifications";
            }
        }
    }

    Component.onCompleted: checkTabs()

    GridLayout {
        id: layout

        anchors.fill: parent
        columns: 1
        rowSpacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: isBarHorizontal ? 1 : 0

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Tab Switcher Header
                Item {
                    id: headerContainer
                    Layout.fillWidth: true
                    implicitHeight: 64
                    clip: true
                    visible: tabRepeater.count > 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: 0

                        Repeater {
                            id: tabRepeater
                            model: {
                                var tabs = [
                                    { id: "notifications", label: qsTr("Notifications"), icon: "notifications" }
                                ];
                                if (root.aiAvailable) {
                                    tabs.push({ id: "ai", label: qsTr("AI Assistant"), icon: "smart_toy" });
                                }
                                if (GlobalConfig.sidebar.showNews !== false) {
                                    tabs.push({ id: "news", label: qsTr("News"), icon: "newspaper" });
                                }
                                return tabs;
                            }

                            delegate: Item {
                                id: tabBtn

                                required property var modelData

                                readonly property bool active: root.activeTab === modelData.id

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                StateLayer {
                                    id: stateLayer
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: Tokens.rounding.medium
                                    color: Colours.palette.m3onSurface
                                    onClicked: root.activeTab = tabBtn.modelData.id
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall - 2

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: tabBtn.modelData.icon
                                        color: tabBtn.active ? Colours.palette.m3primary : stateLayer.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                        fontStyle: Tokens.font.icon.small
                                        fill: tabBtn.active ? 1 : 0
                                        Behavior on fill { Anim { type: Anim.DefaultEffects } }
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: tabBtn.modelData.label
                                        color: tabBtn.active ? Colours.palette.m3primary : stateLayer.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.label.medium
                                    }
                                }
                            }
                        }
                    }

                    // Sliding Indicator
                    Item {
                        id: indicator
                        anchors.verticalCenter: parent.bottom
                        implicitHeight: 6
                        
                        property int activeIndex: {
                            var arr = tabRepeater.model;
                            for (var i = 0; i < arr.length; i++) {
                                if (arr[i].id === root.activeTab) return i;
                            }
                            return 0;
                        }
                        readonly property real tabWidth: (headerContainer.width - Tokens.padding.medium * 2) / tabRepeater.count
                        width: tabWidth - Tokens.padding.medium * 2
                        x: Tokens.padding.medium + activeIndex * tabWidth + (tabWidth - width) / 2

                        clip: true

                        StyledRect {
                            anchors.fill: parent
                            color: Colours.palette.m3primary
                            radius: Tokens.rounding.full
                        }

                        Behavior on x {
                            Anim {}
                        }
                    }
                }

                // Divider
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colours.palette.m3outlineVariant
                    visible: headerContainer.visible
                }

                // Content Panel Stack
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    property int activeIndex: indicator.activeIndex

                    NotifDock {
                        objectName: "sidebarNotifications"
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "notifications" ? 0 : -width
                        opacity: root.activeTab === "notifications" ? 1 : 0
                        visible: opacity > 0
                        props: root.props
                        screenState: root.screenState
                        
                        Behavior on x { Anim { type: Anim.DefaultSpatial } }
                        Behavior on opacity { Anim { type: Anim.DefaultSpatial } }
                    }

                    AiAssistant {
                        id: aiAssistant
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "ai" ? 0 : (indicator.activeIndex < 1 ? width : -width)
                        opacity: root.activeTab === "ai" ? 1 : 0
                        visible: opacity > 0

                        Connections {
                            target: aiAssistant
                            function onIsStreamingChanged() {
                                root.sidebarStreaming = aiAssistant.isStreaming;
                            }
                        }

                        Behavior on x { Anim { type: Anim.DefaultSpatial } }
                        Behavior on opacity { Anim { type: Anim.DefaultSpatial } }
                    }

                    News {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "news" ? 0 : width
                        opacity: root.activeTab === "news" ? 1 : 0
                        visible: opacity > 0
                        
                        Behavior on x { Anim { type: Anim.DefaultSpatial } }
                        Behavior on opacity { Anim { type: Anim.DefaultSpatial } }
                    }
                }
            }
        }

        // Utilities Separator
        StyledRect {
            visible: utilities && utilities.offsetScale < 1
            Layout.row: Config.bar.position === "bottom" ? 0 : (Config.bar.position === "top" ? 2 : 1)
            Layout.topMargin: Config.bar.position === "bottom" ? 0 : (visible ? 18 : 0)
            Layout.bottomMargin: Config.bar.position === "bottom" ? (visible ? 18 : 0) : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }

        // Popout Separator
        StyledRect {
            visible: showPopoutSeparator
            Layout.row: Config.bar.position === "bottom" ? 2 : 0
            Layout.topMargin: Config.bar.position === "top" ? 0 : 12
            Layout.bottomMargin: Config.bar.position === "top" ? 12 : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }
    }
}
