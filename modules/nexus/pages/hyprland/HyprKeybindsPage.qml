import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Blobs
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
    
    title: qsTr("Keybinds")
    isSubPage: true
    
    property var vars: ({})
    
    Component.onCompleted: {
        if (Hypr.usingLua) {
            Quickshell.execDetached(["hyprctl", "eval", "hl.define_submap('record', function() hl.bind('XF86LaunchA', hl.dsp.submap('reset')) end)"]);
        } else {
            Hypr.extras.batchMessage([
                "keyword submap record",
                "keyword bind ,XF86LaunchA,submap,reset",
                "keyword submap reset"
            ]);
        }
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
    component KeybindRow : ConnectedRect {
        id: kroot
        property string label
        property string varKey
        property bool recording: false

        Layout.fillWidth: true
        implicitHeight: contentRow.implicitHeight + contentRow.anchors.margins * 2
        
        StateLayer {
            id: stateLayer
            anchors.fill: parent
            onClicked: {
                kroot.recording = !kroot.recording;
                if (kroot.recording) {
                    focusItem.forceActiveFocus();
                    if (Hypr.usingLua) {
                        Quickshell.execDetached(["hyprctl", "eval", "hl.define_submap('record', function() hl.bind('XF86LaunchA', hl.dsp.submap('reset')) end); hl.dispatch(hl.dsp.submap('record'))"]);
                    } else {
                        Hypr.extras.batchMessage([
                            "keyword submap record",
                            "keyword bind ,XF86LaunchA,submap,reset",
                            "keyword submap reset"
                        ]);
                        Hypr.dispatch("submap record");
                    }
                } else {
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.submap("reset")' : "submap reset");
                }
            }
        }
        
        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    
                    StyledText {
                        text: kroot.label
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                    
                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        font: Tokens.font.icon.small
                        visible: root.vars[kroot.varKey] !== undefined
                        onClicked: root.deleteVar(kroot.varKey)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                StyledText {
                    text: kroot.recording ? "Recording..." : (root.vars[kroot.varKey] !== undefined ? String(root.vars[kroot.varKey]) : (root.defaults[kroot.varKey] !== undefined ? String(root.defaults[kroot.varKey]) : "Unbound"))
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
            
            Item {
                id: recordBtn
                
                implicitWidth: btn.implicitWidth * 0.9
                implicitHeight: btn.implicitHeight * 0.9
                
                BlobGroup {
                    id: blobGroup
                    color: kroot.recording || stateLayer.containsMouse ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest
                    smoothing: kroot.Tokens.rounding.medium
                    cornerFill: false

                    Behavior on color {
                        CAnim {}
                    }
                }
                
                BlobRect {
                    id: btnRect
                    anchors.fill: parent
                    anchors.margins: (stateLayer.containsMouse ? -Tokens.padding.extraSmall : 0) + (kroot.recording ? -Tokens.padding.extraSmall : 0)
                    group: blobGroup
                    radius: kroot.recording ? Tokens.rounding.large : Tokens.rounding.medium

                    Behavior on anchors.margins {
                        Anim {}
                    }

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
                
                Item {
                    id: btn
                    anchors.centerIn: parent
                    implicitWidth: implicitHeight
                    implicitHeight: icon.implicitHeight + Tokens.padding.extraSmall * 2
                    
                    MaterialIcon {
                        id: icon
                        anchors.centerIn: parent
                        text: kroot.recording ? "stop_circle" : "screen_record"
                        color: kroot.recording || stateLayer.containsMouse ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }
        }
        
        Item {
            id: focusItem
            focus: kroot.recording
            property bool modifierOnly: false
            property var lastMods: []
            
            Keys.onPressed: (event) => {
                if (!kroot.recording) return;
                let k = event.key;
                if (k === Qt.Key_Escape) {
                    kroot.recording = false;
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.submap("reset")' : "submap reset");
                    event.accepted = true;
                    return;
                }
                
                let mods = [];
                if (event.modifiers & Qt.ControlModifier) mods.push("CTRL");
                if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT");
                if (event.modifiers & Qt.AltModifier) mods.push("ALT");
                if (event.modifiers & Qt.MetaModifier) mods.push("SUPER");
                
                let keyStr = "";
                if (k >= Qt.Key_A && k <= Qt.Key_Z) {
                    keyStr = String.fromCharCode(k);
                } else if (k >= Qt.Key_0 && k <= Qt.Key_9) {
                    keyStr = String.fromCharCode(k);
                } else {
                    let map = {
                        [Qt.Key_Return]: "Return",
                        [Qt.Key_Enter]: "Return",
                        [Qt.Key_Space]: "Space",
                        [Qt.Key_Tab]: "Tab",
                        [Qt.Key_Backtab]: "Tab",
                        [Qt.Key_Backspace]: "Backspace",
                        [Qt.Key_Minus]: "minus",
                        [Qt.Key_Equal]: "equal",
                        [Qt.Key_BracketLeft]: "bracketleft",
                        [Qt.Key_BracketRight]: "bracketright",
                        [Qt.Key_Semicolon]: "semicolon",
                        [Qt.Key_Apostrophe]: "apostrophe",
                        [Qt.Key_Grave]: "grave",
                        [Qt.Key_Slash]: "slash",
                        [Qt.Key_Period]: "period",
                        [Qt.Key_Backslash]: "backslash",
                        [Qt.Key_Comma]: "comma",
                        [Qt.Key_Right]: "Right",
                        [Qt.Key_Left]: "Left",
                        [Qt.Key_Up]: "Up",
                        [Qt.Key_Down]: "Down",
                        [Qt.Key_Delete]: "Delete"
                    };
                    if (map[k] !== undefined) keyStr = map[k];
                    else keyStr = event.text.toUpperCase();
                }

                let isModKey = (k === Qt.Key_Control || k === Qt.Key_Shift || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R);

                if (keyStr !== "" && !isModKey) {
                    modifierOnly = false;
                    mods.push(keyStr);
                    let finalBind = mods.join(" + ");
                    root.saveVar(kroot.varKey, finalBind);
                    kroot.recording = false;
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.submap("reset")' : "submap reset");
                    event.accepted = true;
                } else if (isModKey) {
                    modifierOnly = true;
                    let modStr = "";
                    if (k === Qt.Key_Control) modStr = "CTRL";
                    else if (k === Qt.Key_Shift) modStr = "SHIFT";
                    else if (k === Qt.Key_Alt) modStr = "ALT";
                    else if (k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R) modStr = "SUPER";
                    
                    if (!mods.includes(modStr) && modStr !== "") mods.push(modStr);
                    lastMods = mods;
                    event.accepted = true;
                }
            }
            
            Keys.onReleased: (event) => {
                if (!kroot.recording) return;
                let k = event.key;
                let isModKey = (k === Qt.Key_Control || k === Qt.Key_Shift || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R);
                
                if (isModKey && modifierOnly && lastMods.length > 0) {
                    let finalBind = lastMods.join(" + ");
                    root.saveVar(kroot.varKey, finalBind);
                    kroot.recording = false;
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.submap("reset")' : "submap reset");
                    event.accepted = true;
                }
            }
        }
    }
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Workspaces")
        }
        
        KeybindRow { first: true; label: "Move window to workspace"; varKey: "kbMoveWinToWs" }
        KeybindRow { label: "Move window to workspace group"; varKey: "kbMoveWinToWsGroup" }
        KeybindRow { label: "Go to workspace"; varKey: "kbGoToWs" }
        KeybindRow { label: "Go to workspace group"; varKey: "kbGoToWsGroup" }
        KeybindRow { label: "Next workspace"; varKey: "kbNextWs" }
        KeybindRow { last: true; label: "Previous workspace"; varKey: "kbPrevWs" }
        
        SectionHeader {
            text: qsTr("Window Group")
        }
        
        KeybindRow { first: true; label: "Cycle next in group"; varKey: "kbWindowGroupCycleNext" }
        KeybindRow { label: "Cycle previous in group"; varKey: "kbWindowGroupCyclePrev" }
        KeybindRow { label: "Ungroup"; varKey: "kbUngroup" }
        KeybindRow { last: true; label: "Toggle group"; varKey: "kbToggleGroup" }
        
        SectionHeader {
            text: qsTr("Window Action")
        }
        
        KeybindRow { first: true; label: "Move window"; varKey: "kbMoveWindow" }
        KeybindRow { label: "Resize window"; varKey: "kbResizeWindow" }
        KeybindRow { label: "Picture-in-picture"; varKey: "kbWindowPip" }
        KeybindRow { label: "Pin window"; varKey: "kbPinWindow" }
        KeybindRow { label: "Fullscreen"; varKey: "kbWindowFullscreen" }
        KeybindRow { label: "Bordered fullscreen"; varKey: "kbWindowBorderedFullscreen" }
        KeybindRow { label: "Toggle floating"; varKey: "kbToggleWindowFloating" }
        KeybindRow { last: true; label: "Close window"; varKey: "kbCloseWindow" }

        SectionHeader {
            text: qsTr("Special Workspaces")
        }
        
        KeybindRow { first: true; label: "Special workspace toggle"; varKey: "kbSpecialWs" }
        KeybindRow { label: "System monitor"; varKey: "kbSystemMonitorWs" }
        KeybindRow { label: "Music"; varKey: "kbMusicWs" }
        KeybindRow { label: "Communication"; varKey: "kbCommunicationWs" }
        KeybindRow { last: true; label: "To-do"; varKey: "kbTodoWs" }

        SectionHeader {
            text: qsTr("Apps")
        }
        
        KeybindRow { first: true; label: "Terminal"; varKey: "kbTerminal" }
        KeybindRow { label: "Browser"; varKey: "kbBrowser" }
        KeybindRow { label: Tr.tr("Code editor"); varKey: "kbEditor" }
        KeybindRow { last: true; label: "File Explorer"; varKey: "kbFileExplorer" }
        
        SectionHeader {
            text: qsTr("Misc")
        }
        
        KeybindRow { first: true; label: "Session menu"; varKey: "kbSession" }
        KeybindRow { label: "Show sidebar"; varKey: "kbShowSidebar" }
        KeybindRow { label: "Clear notifications"; varKey: "kbClearNotifs" }
        KeybindRow { label: "Show panels"; varKey: "kbShowPanels" }
        KeybindRow { label: "Lock screen"; varKey: "kbLock" }
        KeybindRow { last: true; label: "Restore lock screen"; varKey: "kbRestoreLock" }
        
        Item { Layout.preferredHeight: Tokens.padding.large; Layout.fillWidth: true }
    }
}
