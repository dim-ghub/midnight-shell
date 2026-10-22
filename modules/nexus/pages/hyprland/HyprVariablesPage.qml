import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root
    
    title: qsTr("Variables")
    isSubPage: true
    
    property var vars: ({})
    
    Component.onCompleted: {
        loadVars();
    }
    
    property var defaults: ({})
    
    readonly property string configPath: Quickshell.env("HOME") + "/.config/caelestia/hypr-vars.lua"
    readonly property string defaultsPath: Quickshell.env("HOME") + "/.config/hypr/variables.lua"

    function saveVar(key, val) {
        if (typeof val === "boolean") val = val ? "true" : "false";
        else if (typeof val === "string" && !val.startsWith("rgba")) val = '"' + val + '"';
        
        let content = "";
        if (CUtils.fileExists(configPath)) {
            content = CUtils.readFile(configPath);
        }
        if (!content) {
            content = "return {\n}";
        }
        
                let currentVars = {};
        let lines = content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let match = lines[i].match(/^\s*([a-zA-Z0-9_]+)\s*=\s*(.+?)\s*,?$/);
            if (match && match[1] !== "return" && match[1] !== "local") {
                currentVars[match[1]] = match[2];
            }
        }
        
        currentVars[key] = val;
        
        let needsScheme = false;
        for (let k in currentVars) {
            if (String(currentVars[k]).includes("scheme.")) needsScheme = true;
        }
        
        let newContent = needsScheme ? 'local scheme = require("scheme.current")\n\nreturn {\n' : 'return {\n';
        let written = {};
        
        let schema = [
            { cat: "Apps", keys: ["terminal", "browser", "editor", "fileExplorer", "audioSettings"] },
            { cat: "Touchpad", keys: ["touchpadDisableTyping", "touchScrollFactor", "gestureFingers", "workspaceSwipeFingers", "gestureFingersMore"] },
            { cat: "Blur", keys: ["blurEnabled", "blurSpecialWs", "blurPopups", "blurInputMethods", "blurSize", "blurPasses", "blurXray"] },
            { cat: "Shadow", keys: ["shadowEnabled", "shadowRange", "shadowRenderPower", "shadowColour"] },
            { cat: "Gaps", keys: ["workspaceGaps", "windowGapsIn", "windowGapsOut", "singleWindowGapsOut"] },
            { cat: "Window styling", keys: ["windowOpacity", "windowRounding", "windowBorderSize", "activeWindowBorderColour", "inactiveWindowBorderColour"] },
            { cat: "Misc", keys: ["volumeStep", "cursorTheme", "cursorSize", "sleepGestureCmd"] },
            
            { cat: "Workspaces", keys: ["kbMoveWinToWs", "kbMoveWinToWsGroup", "kbGoToWs", "kbGoToWsGroup", "kbNextWs", "kbPrevWs"] },
            { cat: "Window Group", keys: ["kbWindowGroupCycleNext", "kbWindowGroupCyclePrev", "kbUngroup", "kbToggleGroup"] },
            { cat: "Window Action", keys: ["kbMoveWindow", "kbResizeWindow", "kbWindowPip", "kbPinWindow", "kbWindowFullscreen", "kbWindowBorderedFullscreen", "kbToggleWindowFloating", "kbCloseWindow"] },
            { cat: "Special workspaces toggles", keys: ["kbSpecialWs", "kbSystemMonitorWs", "kbMusicWs", "kbCommunicationWs", "kbTodoWs"] },
            { cat: "Apps (Keybinds)", keys: ["kbTerminal", "kbBrowser", "kbEditor", "kbFileExplorer"] },
            { cat: "Misc (Keybinds)", keys: ["kbSession", "kbShowSidebar", "kbClearNotifs", "kbShowPanels", "kbLock", "kbRestoreLock"] }
        ];
        
        for (let c = 0; c < schema.length; c++) {
            let cat = schema[c];
            let catHasVars = false;
            
            for (let k = 0; k < cat.keys.length; k++) {
                let kName = cat.keys[k];
                if (currentVars[kName] !== undefined) {
                    if (!catHasVars) {
                        newContent += "    -- " + cat.cat + "\n";
                        catHasVars = true;
                    }
                    newContent += "    " + kName.padEnd(26) + " = " + currentVars[kName] + ",\n";
                    written[kName] = true;
                }
            }
            if (catHasVars) newContent += "\n";
        }
        
        let customHasVars = false;
        for (let kName in currentVars) {
            if (!written[kName]) {
                if (!customHasVars) {
                    newContent += "    -- Custom\n";
                    customHasVars = true;
                }
                newContent += "    " + kName.padEnd(26) + " = " + currentVars[kName] + ",\n";
            }
        }
        
        newContent = newContent.replace(/\s+$/, "") + "\n}\n";
        
        try {
            CUtils.writeFile(configPath, newContent);
        } catch (e) {
            console.log("Could not write file natively yet: " + e);
            Quickshell.execDetached(["bash", "-c", "cat << 'EOF' > " + configPath + "\n" + newContent + "\nEOF"]);
        }
        loadVars();
    }

    function deleteVar(key) {
        if (!CUtils.fileExists(configPath)) return;
        let content = CUtils.readFile(configPath);
        if (!content) return;
        
        let currentVars = {};
        let lines = content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let match = lines[i].match(/^\s*([a-zA-Z0-9_]+)\s*=\s*(.+?)\s*,?$/);
            if (match && match[1] !== "return" && match[1] !== "local") {
                currentVars[match[1]] = match[2];
            }
        }
        
        if (currentVars[key] === undefined) return;
        delete currentVars[key];
        
        let needsScheme = false;
        for (let k in currentVars) {
            if (String(currentVars[k]).includes("scheme.")) needsScheme = true;
        }
        
        let newContent = needsScheme ? 'local scheme = require("scheme.current")\n\nreturn {\n' : 'return {\n';
        let written = {};
        
        let schema = [
            { cat: "Apps", keys: ["terminal", "browser", "editor", "fileExplorer", "audioSettings"] },
            { cat: "Touchpad", keys: ["touchpadDisableTyping", "touchScrollFactor", "gestureFingers", "workspaceSwipeFingers", "gestureFingersMore"] },
            { cat: "Blur", keys: ["blurEnabled", "blurSpecialWs", "blurPopups", "blurInputMethods", "blurSize", "blurPasses", "blurXray"] },
            { cat: "Shadow", keys: ["shadowEnabled", "shadowRange", "shadowRenderPower", "shadowColour"] },
            { cat: "Gaps", keys: ["workspaceGaps", "windowGapsIn", "windowGapsOut", "singleWindowGapsOut"] },
            { cat: "Window styling", keys: ["windowOpacity", "windowRounding", "windowBorderSize", "activeWindowBorderColour", "inactiveWindowBorderColour"] },
            { cat: "Misc", keys: ["volumeStep", "cursorTheme", "cursorSize", "sleepGestureCmd"] },
            
            { cat: "Workspaces", keys: ["kbMoveWinToWs", "kbMoveWinToWsGroup", "kbGoToWs", "kbGoToWsGroup", "kbNextWs", "kbPrevWs"] },
            { cat: "Window Group", keys: ["kbWindowGroupCycleNext", "kbWindowGroupCyclePrev", "kbUngroup", "kbToggleGroup"] },
            { cat: "Window Action", keys: ["kbMoveWindow", "kbResizeWindow", "kbWindowPip", "kbPinWindow", "kbWindowFullscreen", "kbWindowBorderedFullscreen", "kbToggleWindowFloating", "kbCloseWindow"] },
            { cat: "Special workspaces toggles", keys: ["kbSpecialWs", "kbSystemMonitorWs", "kbMusicWs", "kbCommunicationWs", "kbTodoWs"] },
            { cat: "Apps (Keybinds)", keys: ["kbTerminal", "kbBrowser", "kbEditor", "kbFileExplorer"] },
            { cat: "Misc (Keybinds)", keys: ["kbSession", "kbShowSidebar", "kbClearNotifs", "kbShowPanels", "kbLock", "kbRestoreLock"] }
        ];
        
        for (let c = 0; c < schema.length; c++) {
            let cat = schema[c];
            let catHasVars = false;
            
            for (let k = 0; k < cat.keys.length; k++) {
                let kName = cat.keys[k];
                if (currentVars[kName] !== undefined) {
                    if (!catHasVars) {
                        newContent += "    -- " + cat.cat + "\n";
                        catHasVars = true;
                    }
                    newContent += "    " + kName.padEnd(26) + " = " + currentVars[kName] + ",\n";
                    written[kName] = true;
                }
            }
            if (catHasVars) newContent += "\n";
        }
        
        let customHasVars = false;
        for (let kName in currentVars) {
            if (!written[kName]) {
                if (!customHasVars) {
                    newContent += "    -- Custom\n";
                    customHasVars = true;
                }
                newContent += "    " + kName.padEnd(26) + " = " + currentVars[kName] + ",\n";
            }
        }
        
        newContent = newContent.replace(/\s+$/, "") + "\n}\n";
        
        try {
            CUtils.writeFile(configPath, newContent);
        } catch (e) {
            console.log("Could not write file natively yet: " + e);
            Quickshell.execDetached(["bash", "-c", "cat << 'EOF' > " + configPath + "\n" + newContent + "\nEOF"]);
        }
        loadVars();
    }
    
    function loadVars() {
        let defContent = CUtils.readFile(defaultsPath);
        let dVars = {};
        if (defContent) {
            let dLines = defContent.split("\n");
            for (let i = 0; i < dLines.length; i++) {
                let line = dLines[i].trim();
                let match = line.match(/^([a-zA-Z0-9_]+)\s*=\s*(.+?)\s*,?$/);
                if (match) {
                    let key = match[1], val = match[2];
                    if (val === "true") val = true;
                    else if (val === "false") val = false;
                    else if (val.startsWith("\"") && val.endsWith("\"")) val = val.substring(1, val.length - 1);
                    else if (!isNaN(parseFloat(val))) val = parseFloat(val);
                    dVars[key] = val;
                }
            }
        }
        root.defaults = dVars;
        
        let content = "";
        if (CUtils.fileExists(configPath)) {
            content = CUtils.readFile(configPath);
        }
        let newVars = {};
        if (content) {
            let textLines = content.split("\n");
            for (let i = 0; i < textLines.length; i++) {
                let line = textLines[i].trim();
                let match = line.match(/^([a-zA-Z0-9_]+)\s*=\s*(.+?)\s*,?$/);
                if (match) {
                    let key = match[1], val = match[2];
                    if (val === "true") val = true;
                    else if (val === "false") val = false;
                    else if (val.startsWith("\"") && val.endsWith("\"")) val = val.substring(1, val.length - 1);
                    else if (!isNaN(parseFloat(val))) val = parseFloat(val);
                    newVars[key] = val;
                }
            }
        }
        root.vars = newVars;
    }
    

    component StringRow : ConnectedRect {
        id: sroot
        property string label
        property string subtext
        property string varKey
        
        Layout.fillWidth: true
        implicitHeight: contentRow.implicitHeight + Tokens.padding.medium * 2
        
        RowLayout {
            id: contentRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium
            
            Column {
                Layout.fillWidth: true
                spacing: 0
                
                RowLayout {
                    width: parent.width
                    spacing: Tokens.spacing.small
                    
                    StyledText {
                        text: sroot.label
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                    
                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        font: Tokens.font.icon.small
                        visible: root.vars[sroot.varKey] !== undefined
                        onClicked: root.deleteVar(sroot.varKey)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
                
                StyledText {
                    text: sroot.subtext
                    visible: text !== ""
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                    elide: Text.ElideRight
                }
            }
            
            StyledTextField {
                Layout.preferredWidth: 350
                Layout.alignment: Qt.AlignVCenter
                text: root.vars[sroot.varKey] !== undefined ? String(root.vars[sroot.varKey]) : ""
                placeholderText: root.defaults[sroot.varKey] !== undefined ? String(root.defaults[sroot.varKey]) : ""
                onEditingFinished: {
                    if (text === "") root.deleteVar(sroot.varKey);
                    else root.saveVar(sroot.varKey, text);
                }
            }
        }
    }

    component BoundedSliderRow : SliderRow {
        id: bsroot
        property string varKey
        property real from: 0
        property real to: 1
        property real step: 0.1
        
        showDelete: root.vars[varKey] !== undefined
        onDeleted: root.deleteVar(varKey)
        
        value: {
            let v = root.vars[varKey] !== undefined ? root.vars[varKey] : root.defaults[varKey];
            if (v === undefined) return 0;
            return (v - from) / (to - from);
        }
        valueLabel: {
            let v = root.vars[varKey] !== undefined ? root.vars[varKey] : root.defaults[varKey];
            return v !== undefined ? Number(v).toFixed(step < 1 ? 2 : 0) : "";
        }
        
        onMoved: v => {
            let mapped = from + v * (to - from);
            mapped = Math.round(mapped / step) * step;
            if (step >= 1) mapped = Math.round(mapped);
            // Limit to fixed decimals to avoid precision issues
            mapped = Number(mapped.toFixed(step < 1 ? 2 : 0));
            root.saveVar(varKey, mapped);
        }
    }

    component FloatRow : ConnectedRect {
        id: nroot
        property string label
        property string subtext
        property string varKey
        
        Layout.fillWidth: true
        implicitHeight: ncontentRow.implicitHeight + Tokens.padding.medium * 2
        
        RowLayout {
            id: ncontentRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium
            
            Column {
                Layout.fillWidth: true
                spacing: 0
                
                RowLayout {
                    width: parent.width
                    spacing: Tokens.spacing.small
                    
                    StyledText {
                        text: nroot.label
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                    
                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        font: Tokens.font.icon.small
                        visible: root.vars[nroot.varKey] !== undefined
                        onClicked: root.deleteVar(nroot.varKey)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
                
                StyledText {
                    text: nroot.subtext
                    visible: text !== ""
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                    elide: Text.ElideRight
                }
            }
            
            StyledTextField {
                Layout.preferredWidth: 350
                Layout.alignment: Qt.AlignVCenter
                text: root.vars[nroot.varKey] !== undefined ? String(root.vars[nroot.varKey]) : ""
                placeholderText: root.defaults[nroot.varKey] !== undefined ? String(root.defaults[nroot.varKey]) : ""
                onEditingFinished: {
                    if (text === "") root.deleteVar(nroot.varKey);
                    else if (!isNaN(parseFloat(text))) root.saveVar(nroot.varKey, parseFloat(text));
                }
            }
        }
    }
    
    component IntRow : StepperRow {
        property string varKey
        showDelete: root.vars[varKey] !== undefined
        onDeleted: root.deleteVar(varKey)
        value: root.vars[varKey] !== undefined ? Number(root.vars[varKey]) : (root.defaults[varKey] !== undefined ? Number(root.defaults[varKey]) : 0)
        onMoved: v => root.saveVar(varKey, Math.round(v))
    }
    
    component AppRow: PopupRow {
        id: aroot

        property string varKey
        showDelete: root.vars[varKey] !== undefined
        onDeleted: root.deleteVar(varKey)
        readonly property int popupHeight: root.flickable.height - y + root.flickable.contentY - Tokens.padding.large - Tokens.padding.extraExtraLarge

        keepPopupAsChild: {
            if (!aroot.popup.open && aroot.popup.animDriver === 0)
                return true;

            if (root.nState.animatingContainer || root.opacity < 1)
                return true;

            let p = root.parent;
            while (p && p.objectName !== "PageContainer")
                p = p.parent;
            return p ? (p.opacity < 1) : false;
        }
        popup.topMovement: Math.max(Tokens.sizes.nexus.minPopupHeight - popupHeight, Tokens.padding.large)

        status: root.vars[aroot.varKey] !== undefined ? String(root.vars[aroot.varKey]) : (root.defaults[aroot.varKey] !== undefined ? String(root.defaults[aroot.varKey]) : "")

        Loader {
            anchors.centerIn: parent
            active: aroot.popup.animDriver > 0

            sourceComponent: VerticalFadeListView {
                id: list

                implicitWidth: Tokens.sizes.nexus.popupWidth
                implicitHeight: CUtils.clamp(aroot.popupHeight, Tokens.sizes.nexus.minPopupHeight, Tokens.sizes.nexus.maxPopupHeight)

                model: {
                    const apps = [...DesktopEntries.applications.values];
                    const favourited = new Set(apps.filter(a => Strings.testRegexList(GlobalConfig.launcher.favouriteApps, a.id)));
                    return apps.sort((a, b) => (favourited.has(b) - favourited.has(a)) || a.name.localeCompare(b.name));
                }

                delegate: StateLayer {
                    id: appItem

                    required property DesktopEntry modelData
                    required property int index

                    anchors.fill: undefined
                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    implicitHeight: itemLayout.implicitHeight + itemLayout.anchors.margins * 2
                    radius: Tokens.rounding.small

                    onClicked: {
                        aroot.popup.open = false;
                        root.saveVar(aroot.varKey, modelData.command);
                    }

                    RowLayout {
                        id: itemLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        IconImage {
                            asynchronous: true
                            implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                            source: Quickshell.iconPath(appItem.modelData.icon, "image-missing")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: appItem.modelData.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text
                                text: (appItem.modelData.comment || appItem.modelData.genericName) ?? ""
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        MaterialIcon {
                            visible: Strings.testRegexList(GlobalConfig.launcher.favouriteApps, appItem.modelData.id)
                            text: "favorite"
                            fill: 1
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }
                    }
                }
            }
        }
    }


    component BoolRow : ToggleRow {
        property string varKey
        showDelete: root.vars[varKey] !== undefined
        onDeleted: root.deleteVar(varKey)
        checked: root.vars[varKey] === true
        onToggled: root.saveVar(varKey, checked)
    }
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2
        
        SectionHeader {
            first: true
            text: qsTr("Apps")
        }
        
        AppRow { first: true; icon: "terminal"; label: "Terminal"; varKey: "terminal" }
        AppRow { icon: "public"; label: "Browser"; varKey: "browser" }
        AppRow { icon: "code"; label: Tr.tr("Code editor"); varKey: "editor" }
        AppRow { icon: "folder"; label: "File Explorer"; varKey: "fileExplorer" }
        AppRow { last: true; icon: "volume_up"; label: "Audio Settings"; varKey: "audioSettings" }
        
        SectionHeader {
            text: qsTr("Touchpad")
        }
        
        BoolRow { first: true; text: "Disable typing"; varKey: "touchpadDisableTyping" }
        FloatRow { label: "Scroll factor"; varKey: "touchScrollFactor" }
        IntRow { label: "Gesture fingers"; varKey: "gestureFingers"; from: 1; to: 10 }
        IntRow { label: "Workspace swipe fingers"; varKey: "workspaceSwipeFingers"; from: 1; to: 10 }
        IntRow { last: true; label: "Gesture fingers more"; varKey: "gestureFingersMore"; from: 1; to: 10 }
        
        SectionHeader {
            text: qsTr("Blur")
        }
        
        BoolRow { first: true; text: "Blur enabled"; varKey: "blurEnabled" }
        BoolRow { text: "Blur special workspace"; varKey: "blurSpecialWs" }
        BoolRow { text: "Blur popups"; varKey: "blurPopups" }
        BoolRow { text: "Blur input methods"; varKey: "blurInputMethods" }
        IntRow { label: "Blur size"; varKey: "blurSize"; from: 1; to: 100 }
        IntRow { label: "Blur passes"; varKey: "blurPasses"; from: 1; to: 10 }
        BoolRow { last: true; text: "Blur Xray"; varKey: "blurXray" }
        
        SectionHeader {
            text: qsTr("Shadow")
        }
        
        BoolRow { first: true; text: "Shadow enabled"; varKey: "shadowEnabled" }
        IntRow { label: "Shadow range"; varKey: "shadowRange"; from: 1; to: 100 }
        BoundedSliderRow { label: "Shadow render power"; varKey: "shadowRenderPower"; from: 1; to: 4; step: 1 }
        StringRow { last: true; label: "Shadow colour"; varKey: "shadowColour" }
        
        SectionHeader {
            text: qsTr("Gaps")
        }
        
        IntRow { first: true; label: "Workspace gaps"; varKey: "workspaceGaps"; from: 0; to: 100 }
        IntRow { label: "Window gaps in"; varKey: "windowGapsIn"; from: 0; to: 100 }
        IntRow { label: "Window gaps out"; varKey: "windowGapsOut"; from: 0; to: 100 }
        IntRow { last: true; label: "Single window gaps out"; varKey: "singleWindowGapsOut"; from: 0; to: 100 }
        
        SectionHeader {
            text: qsTr("Window styling")
        }
        
        BoundedSliderRow { first: true; label: "Window opacity"; varKey: "windowOpacity"; from: 0; to: 1; step: 0.01 }
        IntRow { label: "Window rounding"; varKey: "windowRounding"; from: 0; to: 100 }
        IntRow { label: "Window border size"; varKey: "windowBorderSize"; from: 0; to: 20 }
        StringRow { label: "Active window border colour"; varKey: "activeWindowBorderColour" }
        StringRow { last: true; label: "Inactive window border colour"; varKey: "inactiveWindowBorderColour" }
        
        SectionHeader {
            text: qsTr("Misc")
        }
        
        IntRow { first: true; label: "Volume step"; varKey: "volumeStep"; from: 1; to: 100 }
        StringRow { label: "Cursor theme"; varKey: "cursorTheme" }
        IntRow { label: "Cursor size"; varKey: "cursorSize"; from: 8; to: 128 }
        StringRow { last: true; label: "Sleep gesture command"; varKey: "sleepGestureCmd" }
        
        Item { Layout.preferredHeight: Tokens.padding.large; Layout.fillWidth: true }
    }
}
