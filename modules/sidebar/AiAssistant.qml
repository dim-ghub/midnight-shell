pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
import Quickshell
import Quickshell.Io
import M3Shapes
import Caelestia.Blobs

Item {
    id: root

    ListModel { id: chatHistory }
    ListModel { id: historySessionsModel }

    property bool isHistoryTab: false
    property string currentChatId: ""
    property var currentRequest: null
    property bool isStreaming: false
    

    Timer {
        id: typingTimer
        interval: 16
        repeat: true
        property string fullText: ""
        property string currentText: ""
        property int charIndex: 0
        property int targetIdx: -1
        
        onTriggered: {
            if (targetIdx < 0 || targetIdx >= chatHistory.count) {
                stop();
                isTyping = false;
                isThinking = false;
                inAgentLoop = false;
                return;
            }
            if (charIndex >= fullText.length) {
                stop();
                chatHistory.setProperty(targetIdx, "text", fullText);
                chatHistory.setProperty(targetIdx, "isFinished", true);
                saveHistory();
                isTyping = false;
                isThinking = false;
                inAgentLoop = false;
                return;
            }
            var chunkSize = Math.max(1, Math.ceil(fullText.length / 30));
            currentText += fullText.substr(charIndex, chunkSize);
            charIndex += chunkSize;
            chatHistory.setProperty(targetIdx, "text", currentText);
            listView.positionViewAtEnd();
        }
    }
    
    onVisibleChanged: {
        if (visible) {
            fetchModels();
        }
    }

    function startTypingAnimation(text) {
        isThinking = false;
        typingTimer.targetIdx = chatHistory.count - 1;
        typingTimer.fullText = text;
        typingTimer.currentText = "";
        typingTimer.charIndex = 0;
        typingTimer.start();
        listView.positionViewAtEnd();
    }

    Component.onCompleted: {
        fetchModels();
        storeDirProc.running = true;
    }

    Component.onDestruction: flushHistory();

    // Provider management (ollama / openrouter / openclaw)
    readonly property string activeProvider: {
        var p = GlobalConfig.ai.activeProvider || "ollama";
        var ollamaOk = GlobalConfig.ai.enableOllama !== false;
        var openRouterOk = GlobalConfig.ai.enableOpenRouter === true;
        var openClawOk = GlobalConfig.ai.enableOpenClaw === true;

        if ((p === "openrouter" && !openRouterOk) || (p === "openclaw" && !openClawOk) || (p === "ollama" && !ollamaOk)) {
            if (ollamaOk) return "ollama";
            if (openRouterOk) return "openrouter";
            if (openClawOk) return "openclaw";
            return "ollama";
        }
        return p;
    }

    readonly property string currentModel: {
        if (activeProvider === "openrouter") return GlobalConfig.ai.openRouterModel || "openrouter/auto";
        if (activeProvider === "openclaw") return GlobalConfig.ai.openClawModel || "openclaw/default";
        return GlobalConfig.ai.defaultOllamaModel || "llama3";
    }

    readonly property string providerLabel: {
        if (activeProvider === "openrouter") return "OpenRouter";
        if (activeProvider === "openclaw") return "OpenClaw";
        return "Ollama";
    }

    readonly property var providerList: {
        var list = [];
        if (GlobalConfig.ai.enableOllama !== false)
            list.push({ "id": "ollama", "label": qsTr("Local (Ollama)"), "icon": "memory" });
        if (GlobalConfig.ai.enableOpenRouter === true)
            list.push({ "id": "openrouter", "label": qsTr("OpenRouter"), "icon": "public" });
        if (GlobalConfig.ai.enableOpenClaw === true)
            list.push({ "id": "openclaw", "label": qsTr("OpenClaw"), "icon": "hub" });
        if (list.length === 0)
            list.push({ "id": "ollama", "label": qsTr("Local (Ollama)"), "icon": "memory" });
        return list;
    }

    readonly property var fallbackModelsFor: ({
        "openrouter": ["openrouter/auto", "openai/gpt-4o-mini", "anthropic/claude-3.5-haiku", "google/gemini-2.0-flash-001"],
        "openclaw": ["openclaw/default"],
        "ollama": ["llama3", "mistral", "phi3", "gemma"]
    })

    property var modelsByProvider: ({})
    property var modelFetchState: ({})

    readonly property bool modelsLoading: {
        for (var key in modelFetchState) {
            if (modelFetchState[key] === "loading") return true;
        }
        return false;
    }

    property bool selectorOpen: false

    readonly property bool chipMinimized: selectorOpen || inputArea.text.length > 0

    property string modelQuery: ""

    Timer {
        id: searchDebounce
        interval: 200
        onTriggered: root.modelQuery = modelSearch.text
    }

    readonly property string activeProviderIcon: {
        for (var i = 0; i < providerList.length; i++) {
            if (providerList[i].id === activeProvider)
                return providerList[i].icon;
        }
        return "memory";
    }

    // Selector sections render as collapsible dropdowns. Fixed order keeps the
    // local models at the top and OpenRouter's long list at the bottom.
    readonly property var orderedSections: {
        var secs = [];
        var recents = recentEntries;
        if (recents.length > 0)
            secs.push({ "id": "recent", "label": qsTr("Recent"), "icon": "history", "models": recents });

        var order = ["ollama", "openclaw", "openrouter"];
        var byId = {};
        for (var p = 0; p < providerList.length; p++)
            byId[providerList[p].id] = providerList[p];
        for (var i = 0; i < order.length; i++) {
            var pid = order[i];
            if (!byId[pid]) continue;
            var models = modelsByProvider[pid] || fallbackModelsFor[pid] || [];
            var entries = [];
            for (var m = 0; m < models.length; m++)
                entries.push({ "name": models[m], "lower": models[m].toLowerCase(), "providerId": pid });
            secs.push({ "id": pid, "label": byId[pid].label, "icon": byId[pid].icon, "models": entries });
        }
        return secs;
    }

    readonly property var recentEntries: {
        var raw = GlobalConfig.ai.recentModels || [];
        var out = [];
        for (var i = 0; i < raw.length && out.length < 5; i++) {
            var sep = raw[i].indexOf("|");
            if (sep === -1) continue;
            var pid = raw[i].substring(0, sep);
            var name = raw[i].substring(sep + 1);
            var enabled = pid === "ollama" ? GlobalConfig.ai.enableOllama !== false
                : pid === "openrouter" ? GlobalConfig.ai.enableOpenRouter === true
                : pid === "openclaw" ? GlobalConfig.ai.enableOpenClaw === true : false;
            if (!enabled || !name) continue;
            out.push({ "name": name, "lower": name.toLowerCase(), "providerId": pid });
        }
        return out;
    }

    property var expandedSections: ({})

    readonly property var visibleSections: {
        var query = modelQuery.toLowerCase();
        var secs = [];
        for (var s = 0; s < orderedSections.length; s++) {
            var srcSec = orderedSections[s];
            var rows;
            if (!query) {
                rows = srcSec.models;
            } else {
                rows = [];
                for (var m = 0; m < srcSec.models.length; m++) {
                    if (srcSec.models[m].lower.indexOf(query) !== -1)
                        rows.push(srcSec.models[m]);
                }
            }
            secs.push({ "id": srcSec.id, "label": srcSec.label, "icon": srcSec.icon, "models": rows });
        }
        return secs;
    }

    function isSectionExpanded(sec) {
        if (modelQuery.length > 0) return sec.models.length > 0;
        return expandedSections[sec.id] === true;
    }

    function toggleSection(secId) {
        expandedSections = Object.assign({}, expandedSections, { [secId]: expandedSections[secId] !== true });
    }

    readonly property int searchResultCount: {
        var n = 0;
        for (var s = 0; s < visibleSections.length; s++)
            n += visibleSections[s].models.length;
        return n;
    }

    readonly property int totalModelCount: {
        var n = 0;
        for (var s = 0; s < orderedSections.length; s++) {
            if (orderedSections[s].id === "recent") continue;
            n += orderedSections[s].models.length;
        }
        return n;
    }

    function providerIconForId(providerId) {
        for (var i = 0; i < providerList.length; i++) {
            if (providerList[i].id === providerId)
                return providerList[i].icon;
        }
        return "memory";
    }

    function pushRecentModel(providerId, model) {
        var entry = providerId + "|" + model;
        var raw = GlobalConfig.ai.recentModels || [];
        var list = [];
        for (var i = 0; i < raw.length; i++) {
            if (raw[i] !== entry) list.push(raw[i]);
        }
        list.unshift(entry);
        if (list.length > 5) list = list.slice(0, 5);
        GlobalConfig.ai.recentModels = list;
    }

    onSelectorOpenChanged: {
        if (selectorOpen) {
            fetchModels();
            expandedSections = {};
        } else {
            modelSearch.text = "";
            modelQuery = "";
            inputArea.forceActiveFocus();
        }
    }

    onIsHistoryTabChanged: selectorOpen = false

    property bool isTyping: false
    property bool isThinking: false
    property string currentThoughtText: ""
    property bool isThoughtExpanded: false
    onIsTypingChanged: {
        if (isTyping) listView.positionViewAtEnd();
    }
    property bool inAgentLoop: false

    function runAgentCommand(cmd, type) {
        var processQml = "import QtQuick\n" +
                         "import Quickshell.Io\n" +
                         "Process {\n" +
                         "    id: proc\n" +
                         "    command: [\"sh\", \"-c\", " + JSON.stringify(cmd) + "]\n" +
                         "    property string outStr: \"\"\n" +
                         "    property string errStr: \"\"\n" +
                         "    property bool hasExited: false\n" +
                                                  "    property int exitCode: 0\n" +
                         "    property bool outFinished: false\n" +
                         "    property bool errFinished: false\n" +
                         "    function checkDone() {\n" +
                         "        if (hasExited && outFinished && errFinished) {\n" +
                         "            root.handleAgentProcessResult(" + JSON.stringify(type) + ", proc.outStr, proc.errStr, " + JSON.stringify(cmd) + ", proc.exitCode);\n" +
                         "            proc.destroy();\n" +
                         "        }\n" +
                         "    }\n" +
                         "    stdout: StdioCollector { onStreamFinished: { proc.outStr = text || \"\"; proc.outFinished = true; proc.checkDone(); } }\n" +
                         "    stderr: StdioCollector { onStreamFinished: { proc.errStr = text || \"\"; proc.errFinished = true; proc.checkDone(); } }\n" +
                         "    onExited: code => { proc.exitCode = code; proc.hasExited = true; proc.checkDone(); }\n" +
                         "}";
        var obj = Qt.createQmlObject(processQml, root, "agentProcess");
        obj.running = true;
    }

    property int runningToolsCount: 0
    property int agentRounds: 0
    readonly property int maxAgentRounds: 4
    property var toolResultMap: ({})
    property var toolResultOrder: []

    property var pendingToolCalls: null
    property string pendingAssistantContent: ""

    property bool storeReady: false
    property string lastChatId: ""
    readonly property string storePath: `${Paths.data}/ai/chats.json`
    
    FileView {
        id: chatStore
        path: root.storePath
        preload: false
        printErrors: false

        onLoaded: {
            var data = [];
            try {
                data = JSON.parse(text());
            } catch (e) {
                data = [];
            }
            var legacyFormat = Array.isArray(data);
            root.applyStoreData(data);
            if (legacyFormat)
                root.flushHistory();
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.migrateLegacyHistory();
            else
                root.applyStoreData([]);
        }
    }

    Process {
        id: storeDirProc
        command: ["mkdir", "-p", Paths.data + "/ai"]
        onExited: chatStore.reload()
    }

    Timer {
        id: historySaveTimer
        interval: 400
        onTriggered: root.flushHistory()
    }

    function recordToolResult(toolName, text) {
        var map = Object.assign({}, toolResultMap);
        map[toolName] = (map[toolName] ? map[toolName] + "\n\n" : "") + text;
        toolResultMap = map;
        if (toolResultOrder.indexOf(toolName) === -1)
            toolResultOrder = toolResultOrder.concat([toolName]);
    }

    function handleAgentProcessResult(type, stdout, stderr, cmd, exitCode = 0) {
        if (type.startsWith("exec_")) {
            var toolName = type.substring(5);
            var outText = stdout.trim();
            var errText = stderr.trim();
            if (!outText && !errText) {
                outText = "(Command completed with no output. If it was a background task, it has been launched successfully.)";
            }
            var resultText;
            if (exitCode !== 0) {
                resultText = "TOOL FAILED with exit code " + exitCode + ". Do not retry this call.\nCommand executed: " + cmd + "\nOutput: " + outText + "\nError: " + errText;
            } else {
                resultText = "Command executed: " + cmd + "\nOutput: " + outText + "\nError: " + errText;
            }
            recordToolResult(toolName, resultText);
            runningToolsCount--;
            checkToolsFinished();
        }
    }

    function checkToolsFinished() {
        if (runningToolsCount <= 0) {
            var combined = "";
            for (var i = 0; i < toolResultOrder.length; i++) {
                var tn = toolResultOrder[i];
                combined += "Tool: " + tn + "\nResult: " + toolResultMap[tn] + "\n\n";
            }
            sendPrompt(combined.trim(), true, "multi_tool");
        }
    }

    property string currentActionText: "Thinking..."

    function fetchModels() {
        var list = providerList;
        for (var i = 0; i < list.length; i++)
            fetchProviderModels(list[i].id);
    }

    function fetchProviderModels(providerId) {
        if (modelFetchState[providerId] === "loading" || modelFetchState[providerId] === "done") return;

        var requestUrl;
        if (providerId === "openrouter") {
            requestUrl = (GlobalConfig.ai.openRouterUrl || "https://openrouter.ai/api/v1") + "/models";
        } else if (providerId === "openclaw") {
            requestUrl = (GlobalConfig.ai.openClawUrl || "http://127.0.0.1:18789") + "/v1/models";
        } else {
            requestUrl = (GlobalConfig.ai.ollamaUrl || "http://localhost:11434") + "/api/tags";
        }

        var xhr = new XMLHttpRequest();
        xhr.open("GET", requestUrl, true);
        if (providerId === "openrouter") {
            var key = GlobalConfig.ai.openRouterApiKey || "";
            if (key) {
                xhr.setRequestHeader("Authorization", "Bearer " + key);
                xhr.setRequestHeader("HTTP-Referer", "https://github.com/dim-ghub/midnight-shell");
                xhr.setRequestHeader("X-Title", "midnight-shell");
            }
        } else if (providerId === "openclaw") {
            var token = GlobalConfig.ai.openClawToken || "";
            if (token) {
                xhr.setRequestHeader("Authorization", "Bearer " + token);
            }
        }

        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var list = [];
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        if (providerId === "ollama") {
                            if (response.models) {
                                for (var i = 0; i < response.models.length; i++)
                                    list.push(response.models[i].name);
                            }
                        } else if (response.data) {
                            for (var j = 0; j < response.data.length; j++) {
                                if (response.data[j].id) list.push(response.data[j].id);
                            }
                            list.sort();
                        }
                    } catch (e) {
                        console.log("Error parsing " + providerId + " models: " + e.message);
                    }
                } else {
                    console.log(providerId + " models request failed (status " + xhr.status + ")");
                }

                var succeeded = xhr.status === 200 && list.length > 0;
                if (list.length === 0)
                    list = fallbackModelsFor[providerId] || [];

                modelFetchState = Object.assign({}, modelFetchState, { [providerId]: succeeded ? "done" : "failed" });
                modelsByProvider = Object.assign({}, modelsByProvider, { [providerId]: list });

                var savedModel;
                if (providerId === "openrouter") savedModel = GlobalConfig.ai.openRouterModel;
                else if (providerId === "openclaw") savedModel = GlobalConfig.ai.openClawModel;
                else savedModel = GlobalConfig.ai.defaultOllamaModel;

                if (savedModel && list.indexOf(savedModel) === -1 && list.length > 0) {
                    if (providerId === "openrouter")
                        GlobalConfig.ai.openRouterModel = list.indexOf("openrouter/auto") !== -1 ? "openrouter/auto" : list[0];
                    else if (providerId === "openclaw")
                        GlobalConfig.ai.openClawModel = list.indexOf("openclaw/default") !== -1 ? "openclaw/default" : list[0];
                    else
                        GlobalConfig.ai.defaultOllamaModel = list[0];
                }
            }
        };
        xhr.send();
    }

    property var allChatSessions: []

    function setActiveModel(providerId, model) {
        if (!model) return;
        if (providerId === "openrouter") {
            GlobalConfig.ai.openRouterModel = model;
        } else if (providerId === "openclaw") {
            GlobalConfig.ai.openClawModel = model;
        } else {
            GlobalConfig.ai.defaultOllamaModel = model;
        }
        GlobalConfig.ai.activeProvider = providerId;
        pushRecentModel(providerId, model);
    }

    function createNewChat() {
        typingTimer.stop();
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        isStreaming = false;
        pendingToolCalls = null;
        pendingAssistantContent = "";
        agentRounds = 0;
        currentChatId = "chat_" + Date.now();
        lastChatId = currentChatId;
        chatHistory.clear();
        isHistoryTab = false;
    }

    function loadChat(id) {
        typingTimer.stop();
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        isStreaming = false;
        currentChatId = id;
        chatHistory.clear();
        var found = false;
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === id) {
                var msgs = allChatSessions[i].messages;
                for (var j = 0; j < msgs.length; j++) {
                    // Strictly sanitize incoming JSON data before ListModel append
                    chatHistory.append({
                        "isUser": msgs[j].isUser === true,
                        "text": msgs[j].text || "",
                        "isFinished": msgs[j].isFinished !== false,
                        "thoughtText": msgs[j].thoughtText || ""
                    });
                }
                found = true;
                break;
            }
        }
        if (found)
            restoreSessionProvider(allChatSessions[i]);
        else
            createNewChat();
        isHistoryTab = false;
    }

    function relativeTime(ts) {
        if (!ts) return "";
        var diff = Date.now() - ts;
        if (diff < 0) diff = 0;
        var mins = Math.floor(diff / 60000);
        if (mins < 1) return "Just now";
        if (mins < 60) return mins + "m ago";
        var hours = Math.floor(mins / 60);
        if (hours < 24) return hours + "h ago";
        var days = Math.floor(hours / 24);
        if (days === 1) return "Yesterday";
        if (days < 7) return days + "d ago";
        return Qt.formatDate(new Date(ts), "MMM d");
    }

    function syncHistoryModel() {
        historySessionsModel.clear();
        for (var i = 0; i < allChatSessions.length; i++) {
            var s = allChatSessions[i];
            var msgs = Array.isArray(s.messages) ? s.messages : [];
            var preview = "";
            for (var m = msgs.length - 1; m >= 0; m--) {
                var t = (msgs[m].text || "").replace(/\s+/g, " ").trim();
                if (t) { preview = t; break; }
            }
            if (!preview) {
                for (var n = 0; n < msgs.length; n++) {
                    var th = (msgs[n].thoughtText || "").replace(/\s+/g, " ").trim();
                    if (th) { preview = "…" + th.substring(0, 60); break; }
                }
            }
            if (preview.length > 90)
                preview = preview.substring(0, 90) + "…";
            historySessionsModel.append({
                "id": s.id || "",
                "title": s.title || "New Chat",
                "preview": preview,
                "updated": relativeTime(s.updatedAt || s.createdAt || 0),
                "providerIcon": providerIconForId(s.provider || "ollama")
            });
        }
    }

    function restoreSessionProvider(sess) {
        if (!sess) return;
        var p = sess.provider || "ollama";
        var enabled = p === "openrouter" ? GlobalConfig.ai.enableOpenRouter === true
            : p === "openclaw" ? GlobalConfig.ai.enableOpenClaw === true
            : GlobalConfig.ai.enableOllama !== false;
        if (!enabled) return;
        if (p !== activeProvider)
            GlobalConfig.ai.activeProvider = p;
        if (sess.model) {
            if (p === "openrouter")
                GlobalConfig.ai.openRouterModel = sess.model;
            else if (p === "openclaw")
                GlobalConfig.ai.openClawModel = sess.model;
            else
                GlobalConfig.ai.defaultOllamaModel = sess.model;
        }
    }

    function applyStoreData(data) {
        var chats = Array.isArray(data) ? data : (data && Array.isArray(data.chats) ? data.chats : []);
        lastChatId = (!Array.isArray(data) && data && data.lastChatId) ? String(data.lastChatId) : "";

        allChatSessions = chats.filter(s => s !== null && s.id).map(s => {
            var created = typeof s.createdAt === "number" ? s.createdAt : 0;
            return {
                "id": String(s.id),
                "title": s.title || "New Chat",
                "messages": Array.isArray(s.messages) ? s.messages : [],
                "createdAt": created,
                "updatedAt": typeof s.updatedAt === "number" ? s.updatedAt : created,
                "provider": s.provider || "ollama",
                "model": s.model || ""
            };
        });

        allChatSessions.sort((a, b) => b.updatedAt - a.updatedAt);

        syncHistoryModel();
        storeReady = true;

        var targetId = "";
        if (lastChatId) {
            for (var i = 0; i < allChatSessions.length; i++) {
                if (allChatSessions[i].id === lastChatId) {
                    targetId = lastChatId;
                    break;
                }
            }
        }
        if (!targetId && allChatSessions.length > 0)
            targetId = allChatSessions[0].id;

        if (targetId)
            loadChat(targetId);
        else
            createNewChat();
    }

    function migrateLegacyHistory() {
        var legacy = [];
        try {
            var jsonStr = GlobalConfig.ai.ollamaHistoryJson;
            if (jsonStr) legacy = JSON.parse(jsonStr);
        } catch (e) {
            legacy = [];
        }
        if (!Array.isArray(legacy))
            legacy = [];

        applyStoreData(legacy);
        flushHistory();
    }

    function flushHistory() {
        historySaveTimer.stop();
        if (storeReady)
            chatStore.setText(JSON.stringify({
                "version": 2,
                "lastChatId": currentChatId || lastChatId,
                "chats": allChatSessions
            }));
    }

    function saveHistory() {
        var msgs = [];
        for (var i = 0; i < chatHistory.count; i++) {
            var msg = chatHistory.get(i);
            msgs.push({
                "isUser": msg.isUser === true,
                "text": msg.text || "",
                "isFinished": msg.isFinished !== false,
                "thoughtText": (msg.thoughtText || "").substring(0, 12000)
            });
        }

        if (msgs.length === 0) return;

        var now = Date.now();
        var found = false;
        for (var j = 0; j < allChatSessions.length; j++) {
            if (allChatSessions[j].id === currentChatId) {
                var sess = allChatSessions[j];
                sess.messages = msgs;
                sess.updatedAt = now;
                sess.provider = activeProvider;
                sess.model = currentModel;
                if (!sess.createdAt) sess.createdAt = now;

                allChatSessions.splice(j, 1);
                allChatSessions.unshift(sess);

                if (msgs.length > 1 && (sess.title === "Legacy Chat" || sess.title === "New Chat" || sess.title.indexOf("New Chat") === 0 || !sess.title)) {
                    var firstUser = null;
                    for (var k = 0; k < msgs.length; k++) {
                        if (msgs[k].isUser) { firstUser = msgs[k]; break; }
                    }
                    if (firstUser) {
                        generateChatTitleAsync(currentChatId, firstUser.text);
                    }
                }
                found = true;
                break;
            }
        }

        if (!found) {
            var firstUserMsg = null;
            for (var m = 0; m < msgs.length; m++) {
                if (msgs[m].isUser) { firstUserMsg = msgs[m]; break; }
            }

            allChatSessions.unshift({
                "id": currentChatId || ("chat_" + now),
                "title": "New Chat",
                "messages": msgs,
                "createdAt": now,
                "updatedAt": now,
                "provider": activeProvider,
                "model": currentModel
            });

            if (firstUserMsg) {
                generateChatTitleAsync(currentChatId, firstUserMsg.text);
            }
        }

        while (allChatSessions.length > 100) {
            if (allChatSessions[allChatSessions.length - 1].id === currentChatId) break;
            allChatSessions.pop();
        }

        syncHistoryModel();
        historySaveTimer.restart();
    }

    function deleteChat(id) {
        var idx = -1;
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === id) {
                idx = i;
                break;
            }
        }
        if (idx === -1) return;

        allChatSessions.splice(idx, 1);
        syncHistoryModel();
        flushHistory();

        if (currentChatId === id) {
            chatHistory.clear();
            if (allChatSessions.length > 0) {
                loadChat(allChatSessions[0].id);
            } else {
                createNewChat();
            }
        }
    }

    function clearAllHistory() {
        allChatSessions = [];
        syncHistoryModel();
        flushHistory();
        createNewChat();
    }

    function generateChatTitleAsync(chatId, firstMessage) {
        if (!firstMessage) return;

        if (activeProvider === "openrouter" || activeProvider === "openclaw") {
            generateTitleOpenAiCompatible(chatId, firstMessage, activeProvider);
            return;
        }

        var xhr = new XMLHttpRequest();
        var url = (GlobalConfig.ai.ollamaUrl || "http://localhost:11434") + "/api/generate";
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var parsed = JSON.parse(xhr.responseText);
                    if (parsed.response) {
                        var title = parsed.response.trim().replace(/^"|"$/g, '').replace(/\n/g, ' ');
                        if (title.length > 40) title = title.substring(0, 40) + "...";
                        if (title.length > 0) {
                            updateChatTitle(chatId, title);
                        }
                        return;
                    }
                } catch (e) {}
            }
        };
        
        var safeMsg = firstMessage.substring(0, 200);
        xhr.send(JSON.stringify({
            model: GlobalConfig.ai.defaultOllamaModel || "llama3",
            system: "You are a title generator. Output ONLY a 2-4 word title representing the user's message. NO quotes, NO explanation.",
            prompt: "Message: " + safeMsg + "\nTitle:",
            stream: false
        }));
    }

    function generateTitleOpenAiCompatible(chatId, firstMessage, provider) {
        var xhr = new XMLHttpRequest();
        var url;
        if (provider === "openrouter") {
            url = (GlobalConfig.ai.openRouterUrl || "https://openrouter.ai/api/v1") + "/chat/completions";
        } else {
            url = (GlobalConfig.ai.openClawUrl || "http://127.0.0.1:18789") + "/v1/chat/completions";
        }
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");

        if (provider === "openrouter") {
            var orKey = GlobalConfig.ai.openRouterApiKey || "";
            if (orKey) {
                xhr.setRequestHeader("Authorization", "Bearer " + orKey);
                xhr.setRequestHeader("HTTP-Referer", "https://github.com/dim-ghub/midnight-shell");
                xhr.setRequestHeader("X-Title", "midnight-shell");
            }
        } else {
            var ocToken = GlobalConfig.ai.openClawToken || "";
            if (ocToken) {
                xhr.setRequestHeader("Authorization", "Bearer " + ocToken);
            }
        }

        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var parsed = JSON.parse(xhr.responseText);
                    var content = "";
                    if (parsed.choices && parsed.choices.length > 0 && parsed.choices[0].message) {
                        content = parsed.choices[0].message.content || "";
                    }
                    var title = content.trim().replace(/^"|"$/g, '').replace(/\n/g, ' ');
                    if (title.length > 40) title = title.substring(0, 40) + "...";
                    if (title.length > 0) {
                        updateChatTitle(chatId, title);
                    }
                } catch (e) {}
            }
        };

        var safeMsg = firstMessage.substring(0, 200);
        var body = {
            model: provider === "openrouter" ? (GlobalConfig.ai.openRouterModel || "openrouter/auto") : (GlobalConfig.ai.openClawModel || "openclaw/default"),
            messages: [
                {
                    role: "system",
                    content: "You are a title generator. Output ONLY a 2-4 word title representing the user's message. NO quotes, NO explanation."
                },
                {
                    role: "user",
                    content: "Message: " + safeMsg + "\nTitle:"
                }
            ],
            stream: false
        };
        if (provider === "openclaw") {
            body["user"] = "title_" + chatId;
        }
        xhr.send(JSON.stringify(body));
    }

    function updateChatTitle(chatId, title) {
        if (!title || !chatId) return;

        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === chatId) {
                allChatSessions[i].title = title;
                break;
            }
        }

        syncHistoryModel();
        historySaveTimer.restart();
    }

    function addAiMessage(message) {
        chatHistory.append({
            "isUser": false,
            "text": message || "",
            "isFinished": true,
            "thoughtText": ""
        });
        listView.positionViewAtEnd();
        saveHistory();
    }

    function sendPrompt(promptText, isSystemToolResult = false, toolName = "") {
        if (!promptText.trim()) return;

        if (!isSystemToolResult) {
            pendingToolCalls = null;
            pendingAssistantContent = "";
            agentRounds = 0;
            chatHistory.append({
                "isUser": true,
                "text": promptText || "",
                "isFinished": true,
                "thoughtText": ""
            });
            listView.positionViewAtEnd();
            saveHistory();
        }

        isTyping = true;
        isThinking = true;
        inAgentLoop = true;
        currentThoughtText = "";
        isThoughtExpanded = false;
        
        if (isSystemToolResult) {
            if (toolName === "web_search" || toolName === "read_webpage") {
                currentActionText = "Reading results...";
            } else if (toolName === "get_weather") {
                currentActionText = "Analyzing weather...";
            } else {
                currentActionText = "Thinking...";
            }
        } else {
            currentActionText = "Thinking...";
        }
        var xhr = new XMLHttpRequest();
        root.currentRequest = xhr;

        var provider = root.activeProvider;
        
        var processedTextLength = 0;
        var accumulatedThoughtText = "";
        var accumulatedContentText = "";
        var finalToolCalls = null;
        var openAiToolAccum = {};

        // Unified stream line parser: handles Ollama NDJSON and
        // OpenAI-compatible SSE ("data: {...}") used by OpenRouter / OpenClaw.
        function processStreamLine(rawLine) {
            var line = rawLine.trim();
            if (!line) return true;

            if (line.indexOf("data:") === 0) {
                line = line.substring(5).trim();
                if (!line || line === "[DONE]") return true;
            } else if (line.indexOf("event:") === 0 || line.indexOf("id:") === 0 || line.indexOf(":") === 0) {
                return true;
            }

            var parsed;
            try {
                parsed = JSON.parse(line);
            } catch (e) {
                return false; // partial line, retried when more data arrives
            }

            if (parsed.error) {
                var streamErrMsg = parsed.error.message || (typeof parsed.error === "string" ? parsed.error : JSON.stringify(parsed.error));
                accumulatedContentText += (accumulatedContentText ? "\n\n" : "") + "*[" + streamErrMsg + "]*";
                return true;
            }

            if (parsed.message) {
                // Ollama format
                var chunkReasoning = parsed.message.thinking || parsed.message.reasoning || parsed.message.reasoning_content || "";
                if (chunkReasoning) {
                    accumulatedThoughtText += chunkReasoning;
                }

                var chunkContent = parsed.message.content || "";
                if (chunkContent) {
                    accumulatedContentText += chunkContent;
                }

                if (parsed.message.tool_calls) {
                    finalToolCalls = parsed.message.tool_calls;
                }
            } else if (parsed.choices && parsed.choices.length > 0) {
                // OpenAI-compatible format
                var choice = parsed.choices[0];
                var delta = choice.delta || choice.message || {};

                var chunkReasoning2 = delta.reasoning || delta.reasoning_content || "";
                if (chunkReasoning2) {
                    accumulatedThoughtText += chunkReasoning2;
                }

                var chunkContent2 = delta.content || "";
                if (chunkContent2) {
                    accumulatedContentText += chunkContent2;
                }

                if (delta.tool_calls) {
                    for (var t = 0; t < delta.tool_calls.length; t++) {
                        var tc = delta.tool_calls[t];
                        var tcIdx = (tc.index !== undefined) ? tc.index : 0;
                        if (!openAiToolAccum[tcIdx]) {
                            openAiToolAccum[tcIdx] = { "id": tc.id || "", "name": "", "args": "" };
                        } else if (tc.id && !openAiToolAccum[tcIdx].id) {
                            openAiToolAccum[tcIdx].id = tc.id;
                        }
                        if (tc.function) {
                            if (tc.function.name) openAiToolAccum[tcIdx].name += tc.function.name;
                            if (tc.function.arguments) openAiToolAccum[tcIdx].args += tc.function.arguments;
                        }
                    }
                }
            }
            return true;
        }

        // Normalize accumulated OpenAI-style tool call deltas into the same
        // shape Ollama emits (function.arguments as a parsed object).
        function finalizeToolCalls() {
            if (finalToolCalls === null && Object.keys(openAiToolAccum).length > 0) {
                var calls = [];
                var keys = Object.keys(openAiToolAccum).sort();
                for (var k = 0; k < keys.length; k++) {
                    var entry = openAiToolAccum[keys[k]];
                    var argsObj = {};
                    if (entry.args) {
                        try {
                            argsObj = JSON.parse(entry.args);
                        } catch (e) {
                            argsObj = {};
                        }
                    }
                    calls.push({
                        "id": entry.id || ("call_" + keys[k]),
                        "type": "function",
                        "function": {
                            "name": entry.name,
                            "arguments": argsObj
                        }
                    });
                }
                finalToolCalls = calls;
            }
        }

        function updateChatDisplay() {
            var displayContent = accumulatedContentText;
            var displayThought = accumulatedThoughtText;

            if (accumulatedThoughtText === "") {
                var openThinkIdx = displayContent.indexOf("<think>");
                var closeThinkIdx = displayContent.indexOf("</think>");

                if (openThinkIdx !== -1) {
                    if (closeThinkIdx !== -1) {
                        displayThought = displayContent.substring(openThinkIdx + 7, closeThinkIdx).trim();
                        displayContent = displayContent.substring(0, openThinkIdx) + displayContent.substring(closeThinkIdx + 8);
                    } else {
                        displayThought = displayContent.substring(openThinkIdx + 7).trim();
                        displayContent = displayContent.substring(0, openThinkIdx);
                    }
                }
            }

            root.currentThoughtText = displayThought.trim();

            if (displayContent.trim() !== "") {
                if (isThinking) isThinking = false;
            }

            chatHistory.setProperty(chatHistory.count - 1, "thoughtText", displayThought.trim());
            chatHistory.setProperty(chatHistory.count - 1, "text", displayContent.trim());
            listView.positionViewAtEnd();
        }
        
        for (var i = chatHistory.count - 1; i >= 0; i--) {
            var m = chatHistory.get(i);
            if (!m.isUser && !m.isFinished && m.text === "") {
                chatHistory.remove(i);
            }
        }
        
        chatHistory.append({
            "isUser": false,
            "text": "",
            "isFinished": false,
            "thoughtText": ""
        });
        
        listView.positionViewAtEnd();
        
        xhr.onreadystatechange = () => {
            if (xhr.readyState === 3 || xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var currentText = xhr.responseText;
                    var unparsed = currentText.substring(processedTextLength);
                    var lines = unparsed.split('\n');
                    
                    var linesToProcess = (xhr.readyState === XMLHttpRequest.DONE) ? lines.length : lines.length - 1;
                    
                    for (var i = 0; i < linesToProcess; i++) {
                        var line = lines[i].trim();
                        if (line === "") {
                            processedTextLength += lines[i].length + 1;
                            continue;
                        }
                        
                        if (!processStreamLine(lines[i])) {
                            break;
                        }
                        processedTextLength += lines[i].length + 1;
                        updateChatDisplay();
                    }
                }
                
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        finalizeToolCalls();
                        chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                        saveHistory();
                        
                        if (finalToolCalls && finalToolCalls.length > 0) {
                            var enableTools = GlobalConfig.ai.enableCelestialMode;
                            if (enableTools) {
                                currentActionText = "Using tools...";
                                toolResultMap = {};
                                toolResultOrder = [];
                                runningToolsCount = 0;

                                var calls = [];
                                for (var c = 0; c < finalToolCalls.length; c++) {
                                    var fc = finalToolCalls[c];
                                    var fcName = fc.function ? fc.function.name : "";
                                    var fcArgs = fc.function ? fc.function.arguments : {};
                                    if (typeof fcArgs === "string") {
                                        try {
                                            fcArgs = JSON.parse(fcArgs || "{}");
                                        } catch (e) {
                                            fcArgs = {};
                                        }
                                    }
                                    calls.push({
                                        "id": fc.id || ("call_" + c),
                                        "name": fcName,
                                        "args": fcArgs || {}
                                    });
                                }
                                pendingToolCalls = calls;
                                pendingAssistantContent = accumulatedContentText;
                                agentRounds++;

                                if (agentRounds > maxAgentRounds * 2) {
                                    chatHistory.setProperty(chatHistory.count - 1, "text", "Stopped after " + agentRounds + " tool rounds without a final answer.");
                                    chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                                    isTyping = false;
                                    isThinking = false;
                                    inAgentLoop = false;
                                    isStreaming = false;
                                    saveHistory();
                                    return;
                                }
                                
                                if (agentRounds > maxAgentRounds) {
                                    for (var f = 0; f < calls.length; f++)
                                        recordToolResult(calls[f].name, "Tool use limit reached. Do not call any more tools; answer the user directly now with the information you have.");
                                    checkToolsFinished();
                                    return;
                                }
                                
                                for (var t = 0; t < calls.length; t++) {
                                    var toolName = calls[t].name;
                                    var args = calls[t].args;
                                    
                                    if (toolName === "web_search" || toolName === "read_webpage" || toolName === "open_app" || toolName === "get_weather" || toolName === "caelestia_command") {
                                        runningToolsCount++;
                                    }
                                    
                                    if (toolName === "web_search") {
                                        currentActionText = "Searching the web...";
                                        var query = args.query;
                                        var page = args.page || 1;
                                        runAgentCommand('PYTHONIOENCODING=utf8 python3 "' + Quickshell.shellDir + '/assets/scripts/orion_search.py" --mode search --query "' + query.replace(new RegExp("\"", "g"), '\"') + '" --page ' + page, "exec_" + toolName);
                                    } else if (toolName === "read_webpage") {
                                        currentActionText = "Reading webpage...";
                                        var url = args.url;
                                        runAgentCommand('PYTHONIOENCODING=utf8 python3 "' + Quickshell.shellDir + '/assets/scripts/orion_search.py" --mode read --url "' + url.replace(new RegExp("\"", "g"), '\"') + '"', "exec_" + toolName);
                                    } else if (toolName === "open_app") {
                                        currentActionText = "Opening app...";
                                        var app = args.app_name;
                                        runAgentCommand('grep -i -m 1 "^Exec=" $(find /usr/share/applications ~/.local/share/applications -name "*.desktop" -exec grep -il "Name=.*' + app.replace(new RegExp("\"", "g"), '\"') + '" {} \;) | cut -d "=" -f 2- | sed "s/ %[a-zA-Z]//g" | xargs -I {} sh -c "{} & disown"', "exec_" + toolName);
                                    } else if (toolName === "set_timer") {
                                        currentActionText = "Setting timer...";
                                        var secs = args.seconds || 5;
                                        var msg = args.message || "Timer finished";
                                        var safeMsg = msg.replace(new RegExp("\"", "g"), '\"');
                                        var timerQml = "import QtQuick; Timer { interval: " + (secs * 1000) + "; running: true; onTriggered: { root.runAgentCommand('notify-send \"Orion Timer\" \"" + safeMsg + "\"', \"timer_trigger\"); destroy(); } }";
                                        Qt.createQmlObject(timerQml, root, "timer_" + Date.now());
                                        recordToolResult("set_timer", "Timer successfully set for " + secs + " seconds in the background.");
                                    } else if (toolName === "get_weather") {
                                        currentActionText = "Checking weather...";
                                        var loc = args.location;
                                        runAgentCommand('curl -s "wttr.in/' + loc.replace(new RegExp("\"", "g"), '\"') + '?0T"', "exec_" + toolName);
                                    } else if (toolName === "caelestia_command") {
                                        currentActionText = "Running caelestia...";
                                        var subcmd = args.subcommand || "";
                                        var subargs = args.args || "";
                                        var cmd = "caelestia " + subcmd;
                                        if (subargs) cmd += " " + subargs;
                                        runAgentCommand(cmd, "exec_" + toolName);
                                    }
                                }
                                
                                if (runningToolsCount === 0) {
                                    if (toolResultOrder.length > 0) {
                                        checkToolsFinished();
                                    } else {
                                        currentActionText = "Thinking...";
                                        isTyping = false;
                                        isThinking = false;
                                        inAgentLoop = false;
                                        isStreaming = false;
                                    }
                                }
                            } else {
                                currentActionText = "Thinking...";
                                isTyping = false;
                                isThinking = false;
                                inAgentLoop = false;
                                isStreaming = false;
                            }
                        } else {
                            currentActionText = "Thinking...";
                            isTyping = false;
                            isThinking = false;
                            inAgentLoop = false;
                            isStreaming = false;
                        }
                    } else {
                        var errMsg = (xhr.status === 0) ? "Generation cancelled" : root.providerLabel + " request failed (status " + xhr.status + ").";
                        if (xhr.status !== 0) {
                            try {
                                var errParsed = JSON.parse(xhr.responseText);
                                if (errParsed.error) {
                                    var errDetail = errParsed.error.message || (typeof errParsed.error === "string" ? errParsed.error : "");
                                    if (errDetail) errMsg += " " + errDetail;
                                }
                            } catch (e) {}
                        }
                        var currentText = chatHistory.get(chatHistory.count - 1).text;
                        if (currentText.trim() === "") {
                            chatHistory.setProperty(chatHistory.count - 1, "text", errMsg);
                        } else {
                            chatHistory.setProperty(chatHistory.count - 1, "text", currentText + "\n\n*[" + errMsg + "]*");
                        }
                        chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                        isTyping = false;
                        isThinking = false;
                        inAgentLoop = false;
                        agentRounds = 0;
                        isStreaming = false;
                        saveHistory();
                    }
                }
            }
        };

        var messages = [];
        var enableTools = GlobalConfig.ai.enableCelestialMode;
        var sysPrompt = "You are a helpful AI assistant integrated into the user's OS. You can use tools to assist the user.";
        if (enableTools) {
            sysPrompt += "\nCRITICAL RULES:\n1. You CAN browse the web using the web_search tool.\n2. DO NOT apologize for errors, simply explain what happened.\n3. When using tools, you don't need to explain that you are using a tool, just do it and respond to the user smoothly.\n4. If a tool call fails or returns an error, do NOT retry it and do NOT try workarounds with other tools. Briefly tell the user what failed and answer from your own knowledge if you can.\n5. After tools give you their results, answer the user directly; only call more tools when the request truly needs them.";
        }
        
        messages.push({
            "role": "system",
            "content": sysPrompt
        });

        for (var i = 0; i < chatHistory.count; i++) {
            var msg = chatHistory.get(i);
            if (!msg.isUser && (!msg.text || msg.text.length === 0))
                continue;
            messages.push({
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.text || ""
            });
        }

        if (isSystemToolResult) {
            if (provider !== "ollama" && pendingToolCalls && pendingToolCalls.length > 0) {
                var tcArr = [];
                for (var p = 0; p < pendingToolCalls.length; p++) {
                    tcArr.push({
                        "id": pendingToolCalls[p].id,
                        "type": "function",
                        "function": {
                            "name": pendingToolCalls[p].name,
                            "arguments": JSON.stringify(pendingToolCalls[p].args || {})
                        }
                    });
                }
                messages.push({
                    "role": "assistant",
                    "content": pendingAssistantContent || null,
                    "tool_calls": tcArr
                });

                for (var q = 0; q < pendingToolCalls.length; q++) {
                    var pcName = pendingToolCalls[q].name;
                    messages.push({
                        "role": "tool",
                        "tool_call_id": pendingToolCalls[q].id,
                        "content": toolResultMap[pcName] || "(no output)"
                    });
                }

            } else {
                var toolMsg = {
                    "role": "user",
                    "content": promptText
                };
                messages.push(toolMsg);
            }
            pendingToolCalls = null;
            pendingAssistantContent = "";
        }

        var requestBody = {
            "model": currentModel,
            "messages": messages,
            "stream": true
        };

        if (provider === "openclaw") {
            // Ties the OpenClaw agent session to this conversation
            requestBody["user"] = currentChatId || "midnight-shell-session";
        }
        
        if (enableTools) {
            requestBody["tools"] = [
                {
                    "type": "function",
                    "function": {
                        "name": "web_search",
                        "description": "Searches the web using a headless Firefox browser. Returns the top 5 results with snippets and URLs. Requires the Playwright Firefox browser; if the call fails, tell the user to run: playwright install firefox.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "The search query" },
                                "page": { "type": "number", "description": "The page number to fetch (1-indexed, default is 1)" }
                            },
                            "required": ["query"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "read_webpage",
                        "description": "Navigates to a specific URL and returns the main text content of the page.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": { "type": "string", "description": "The absolute URL to read" }
                            },
                            "required": ["url"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "open_app",
                        "description": "Searches for and launches an application installed on the user's system via its .desktop file.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "app_name": { "type": "string", "description": "The name of the app to launch (e.g. firefox, kitty)" }
                            },
                            "required": ["app_name"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_timer",
                        "description": "Sets a timer that will trigger a desktop notification when finished.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "seconds": { "type": "number", "description": "Duration in seconds" },
                                "message": { "type": "string", "description": "Notification message" }
                            },
                            "required": ["seconds", "message"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_weather",
                        "description": "Gets the current weather for a specific location.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "location": { "type": "string", "description": "City name" }
                            },
                            "required": ["location"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "caelestia_command",
                        "description": "Execute a caelestia CLI command to manage the system. Valid subcommands: shell, toggle, scheme, search, screenshot, record, clipboard, emoji, wallpaper, resizer, install, update.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "subcommand": { "type": "string", "description": "The subcommand to run (e.g., scheme, wallpaper, toggle, record)" },
                                "args": { "type": "string", "description": "Additional arguments to pass to the subcommand" }
                            },
                            "required": ["subcommand"]
                        }
                    }
                }
            ];
        }
        
        var requestUrl;
        if (provider === "openrouter") {
            requestUrl = (GlobalConfig.ai.openRouterUrl || "https://openrouter.ai/api/v1") + "/chat/completions";
        } else if (provider === "openclaw") {
            requestUrl = (GlobalConfig.ai.openClawUrl || "http://127.0.0.1:18789") + "/v1/chat/completions";
        } else {
            requestUrl = (GlobalConfig.ai.ollamaUrl || "http://localhost:11434") + "/api/chat";
        }
        xhr.open("POST", requestUrl, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        
        if (provider === "openrouter") {
            var orKey = GlobalConfig.ai.openRouterApiKey || "";
            if (orKey) {
                xhr.setRequestHeader("Authorization", "Bearer " + orKey);
                xhr.setRequestHeader("HTTP-Referer", "https://github.com/dim-ghub/midnight-shell");
                xhr.setRequestHeader("X-Title", "midnight-shell");
            }
        } else if (provider === "openclaw") {
            var ocToken = GlobalConfig.ai.openClawToken || "";
            if (ocToken) {
                xhr.setRequestHeader("Authorization", "Bearer " + ocToken);
            }
        }
        
        isStreaming = true;
        xhr.send(JSON.stringify(requestBody));
    }

    Item {
        id: mainWrapper
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium

         // Mode Switcher Row (Chat / History)
         RowLayout {
             id: modeSwitcherRow
             anchors.top: parent.top
             anchors.left: parent.left
             anchors.right: parent.right
             anchors.rightMargin: 0
             z: 10
             spacing: Tokens.spacing.small

             StyledRect {
                 id: modeSwitcherBg
                 implicitWidth: modeRow.width
                 implicitHeight: 32
                 radius: Tokens.rounding.full
                 color: Colours.tPalette.m3surfaceContainer

                 StyledClippingRect {
                     z: -1
                     anchors.fill: parent
                     radius: Tokens.rounding.full
                     ShaderEffectSource {
                         id: switcherBlurSource
                         sourceItem: contentStack
                         sourceRect: {
                             var p = parent.mapToItem(contentStack, 0, 0);
                             return Qt.rect(p.x, p.y, parent.width, parent.height);
                         }
                     }
                     MultiEffect {
                         anchors.fill: parent
                         source: switcherBlurSource
                         blurEnabled: true
                         blurMax: 32
                     }
                 }

                 StyledRect {
                     width: isHistoryTab ? historyTab.width : chatTab.width
                     height: parent.height
                     radius: Tokens.rounding.full
                     color: Colours.palette.m3primary
                     x: isHistoryTab ? historyTab.x : chatTab.x
                     
                     Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                     Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                 }

                 Row {
                     id: modeRow
                     height: parent.height

                     Item {
                         id: chatTab
                         height: parent.height
                         width: !isHistoryTab ? 40 : chatContent.implicitWidth + Tokens.padding.medium * 2
                         

                         Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                         StateLayer {
                             radius: Tokens.rounding.full
                             onClicked: isHistoryTab = false
                         }

                         Row {
                             id: chatContent
                             anchors.centerIn: parent
                             spacing: Tokens.spacing.small
                             MaterialIcon {
                                 anchors.verticalCenter: parent.verticalCenter
                                 text: "chat"
                                 color: !isHistoryTab ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.icon.small
                             }
                             Text {
                                 anchors.verticalCenter: parent.verticalCenter
                                 text: "Chat"
                                 color: !isHistoryTab ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.body.small
                                 visible: isHistoryTab
                             }
                         }
                     }

                     Item {
                         id: historyTab
                         height: parent.height
                         width: isHistoryTab ? 40 : historyContent.implicitWidth + Tokens.padding.medium * 2
                         

                         Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                         StateLayer {
                             radius: Tokens.rounding.full
                             onClicked: isHistoryTab = true
                         }

                         Row {
                             id: historyContent
                             anchors.centerIn: parent
                             spacing: Tokens.spacing.small
                             MaterialIcon {
                                 anchors.verticalCenter: parent.verticalCenter
                                 text: "history"
                                 color: isHistoryTab ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.icon.small
                             }
                             Text {
                                 anchors.verticalCenter: parent.verticalCenter
                                 text: "History"
                                 color: isHistoryTab ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                 font: Tokens.font.body.small
                                 visible: !isHistoryTab
                             }
                         }
                     }
                 }
             }

         }
         
         Item {
             id: contentStack
             anchors.top: modeSwitcherRow.bottom
             anchors.bottom: parent.bottom
             anchors.left: parent.left
             anchors.right: parent.right
             anchors.topMargin: Tokens.spacing.medium

             // Chat View
             Item {
                 anchors.fill: parent
                 opacity: !isHistoryTab ? 1 : 0
                 visible: opacity > 0
                 Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                 VerticalFadeListView {
                     id: listView
                     anchors.top: parent.top
                     anchors.bottom: inputBoxRow.top
                     anchors.left: parent.left
                     anchors.right: parent.right
                     anchors.bottomMargin: Tokens.spacing.medium
                     spacing: Tokens.spacing.medium
                     model: chatHistory
                     boundsBehavior: Flickable.StopAtBounds
                     
                     ColumnLayout {
                         anchors.centerIn: parent
                         opacity: chatHistory.count === 0 && !isTyping && !isThinking ? 1.0 : 0.0
                         visible: opacity > 0
                         Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                         spacing: Tokens.spacing.large

                         Item {
                             Layout.alignment: Qt.AlignHCenter
                             implicitWidth: 72
                             implicitHeight: 72

                             Logo {
                                 id: emptyStateLogo
                                 anchors.fill: parent
                                 visible: false // hide original for MultiEffect to take over
                             }

                             MultiEffect {
                                 anchors.fill: parent
                                 source: emptyStateLogo
                                 colorization: 1.0
                                 colorizationColor: Colours.palette.m3primary
                             }
                         }

                         StyledText {
                             id: greetingText
                             Layout.alignment: Qt.AlignHCenter
                             Layout.maximumWidth: listView.width - (Tokens.padding.large * 2)
                             horizontalAlignment: Text.AlignHCenter
                             wrapMode: Text.Wrap
                             font: Tokens.font.title.medium
                             color: Colours.palette.m3onSurfaceVariant

                             property var phrases: [
                                 "Ask away, %1!",
                                 "How can I help you today, %1?",
                                 "What's on your mind, %1?",
                                 "Ready when you are, %1!",
                                 "Let's get started, %1.",
                                 "What shall we explore today, %1?",
                                 "I'm all ears, %1!"
                             ]

                             Component.onCompleted: {
                                 var user = Quickshell.env("USER") || "user";
                                 var userCapitalized = user.charAt(0).toUpperCase() + user.slice(1);
                                 var phrase = phrases[Math.floor(Math.random() * phrases.length)];
                                 text = phrase.replace("%1", userCapitalized);
                             }
                         }
                     }

                     ScrollBar.vertical: StyledScrollBar {
                         flickable: listView
                     }

                     footer: Item {
                         width: listView.width
                         height: isThinking ? bubbleBg.height + Tokens.spacing.medium : 0
                         visible: opacity > 0
                         opacity: isThinking ? 1 : 0
                         
                         Behavior on height { Anim { type: Anim.DefaultSpatial } }
                         Behavior on opacity { Anim { type: Anim.DefaultSpatial } }

                         StyledRect {
                             id: bubbleBg
                             y: Tokens.spacing.medium / 2
                             width: Math.min(listView.width * 0.85, footerCol.implicitWidth + Tokens.padding.medium * 2 + 8)
                             height: footerCol.implicitHeight + Tokens.padding.medium * 2
                             radius: Tokens.rounding.large
                             color: Colours.tPalette.m3surfaceContainer

                             // Asymmetric corners
                             topLeftRadius: Tokens.rounding.large
                             topRightRadius: Tokens.rounding.large
                             bottomLeftRadius: 4
                             bottomRightRadius: Tokens.rounding.large

                             Column {
                                 id: footerCol
                                 anchors.fill: parent
                                 anchors.margins: Tokens.padding.medium
                                 spacing: Tokens.spacing.small
                                 
                                 Row {
                                     spacing: Tokens.spacing.small
                                     
                                     LoadingIndicator {
                                         width: 20
                                         height: 20
                                         color: Colours.palette.m3primary
                                     }
                                     
                                     // M3 Expressive Animated Text Wrapper
                                     Item {
                                         width: mainText.implicitWidth
                                         height: mainText.implicitHeight
                                         // The bubble smoothly expands/shrinks as the text width changes
                                         Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                         
                                         StyledText {
                                             id: mainText
                                             text: displayedText
                                             color: Colours.palette.m3onSurfaceVariant
                                             font: Tokens.font.body.small
                                             
                                             property string displayedText: root.currentActionText
                                             property string nextText: ""

                                             transform: Translate { id: textTrans; y: 0 }
                                             opacity: 1.0

                                             Connections {
                                                 target: root
                                                 function onCurrentActionTextChanged() {
                                                     if (root.currentActionText !== mainText.displayedText) {
                                                         mainText.nextText = root.currentActionText;
                                                         switchAnim.restart();
                                                     }
                                                 }
                                             }

                                             SequentialAnimation {
                                                 id: switchAnim
                                                 ParallelAnimation {
                                                     NumberAnimation { target: textTrans; property: "y"; to: -8; duration: 150; easing.type: Easing.InCubic }
                                                     NumberAnimation { target: mainText; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
                                                 }
                                                 PropertyAction { target: mainText; property: "displayedText"; value: mainText.nextText }
                                                 PropertyAction { target: textTrans; property: "y"; value: 8 }
                                                 ParallelAnimation {
                                                     NumberAnimation { target: textTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                                                     NumberAnimation { target: mainText; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.OutQuad }
                                                 }
                                             }

                                             SequentialAnimation {
                                                 running: isThinking && !switchAnim.running
                                                 loops: Animation.Infinite
                                                 NumberAnimation { target: mainText; property: "opacity"; from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                                                 NumberAnimation { target: mainText; property: "opacity"; from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                             }
                                         }
                                     }
                                     
                                     Item {
                                         visible: root.currentThoughtText !== ""
                                         width: Tokens.spacing.medium
                                         height: 1
                                     }
                                     
                                     Item {
                                         visible: root.currentThoughtText !== ""
                                         width: thoughtRowFooter.implicitWidth
                                         height: thoughtRowFooter.implicitHeight
                                         Row {
                                             id: thoughtRowFooter
                                             spacing: Tokens.spacing.small
                                             MaterialIcon {
                                                 text: "expand_more"
                                                 color: Colours.palette.m3onSurfaceVariant
                                                 font: Tokens.font.icon.small
                                                 rotation: root.isThoughtExpanded ? 180 : 0
                                                 Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                             }
                                         }
                                         MouseArea {
                                             anchors.fill: parent
                                             anchors.margins: -10
                                             cursorShape: Qt.PointingHandCursor
                                             onClicked: root.isThoughtExpanded = !root.isThoughtExpanded
                                         }
                                     }
                                 }
                                 Item {
                                     id: footerThoughtContentWrapper
                                     width: footerThoughtContent.width
                                     height: root.isThoughtExpanded ? footerThoughtContent.implicitHeight : 0
                                     clip: true
                                     
                                     Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                                     TextEdit {
                                         id: footerThoughtContent
                                         width: Math.min(implicitWidth, listView.width * 0.85 - Tokens.padding.medium * 2)
                                         textFormat: Text.MarkdownText
                                         text: root.currentThoughtText
                                         color: Colours.palette.m3onSurfaceVariant
                                         font: Tokens.font.body.small
                                         wrapMode: Text.Wrap
                                         readOnly: true
                                         selectByMouse: true
                                         selectionColor: Colours.palette.m3primary
                                         selectedTextColor: Colours.palette.m3onPrimary
                                         opacity: root.isThoughtExpanded ? 1.0 : 0.0
                                         
                                         Behavior on opacity {
                                             SequentialAnimation {
                                                 PauseAnimation { duration: root.isThoughtExpanded ? 100 : 0 }
                                                 NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                             }
                                         }
                                     }
                                 }
                             }
                         }
                     }

                     delegate: Item {
                         id: delegateItem

                         required property string text
                         required property bool isUser
                         required property bool isFinished
                         required property string thoughtText

                         width: listView.width
                         visible: (!delegateItem.isFinished && isThinking) ? false : (delegateItem.text !== "" || delegateItem.thoughtText !== "")
                         height: visible ? bubbleRect.height : 0
                         
                         scale: 0.0
                         opacity: 0.0
                         
                         Component.onCompleted: {
                             popInAnim.start();
                         }
                         
                         ParallelAnimation {
                             id: popInAnim
                             NumberAnimation { target: delegateItem; property: "scale"; from: 0.8; to: 1.0; duration: 300; easing.type: Easing.OutBack }
                             NumberAnimation { target: delegateItem; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
                         }
                         
                         SequentialAnimation {
                             id: popDoneAnim
                             NumberAnimation { target: delegateItem; property: "scale"; from: 1.0; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
                             NumberAnimation { target: delegateItem; property: "scale"; from: 1.02; to: 1.0; duration: 150; easing.type: Easing.OutSine }
                         }
                         
                         onIsFinishedChanged: {
                             if (isFinished) popDoneAnim.start();
                         }

                         StyledRect {
                             id: bubbleRect
                             readonly property real maxBubbleWidth: delegateItem.width * 0.85
                             anchors.right: delegateItem.isUser ? parent.right : undefined
                             anchors.rightMargin: delegateItem.isUser ? Tokens.padding.large : 0
                             anchors.left: delegateItem.isUser ? undefined : parent.left
                             anchors.leftMargin: delegateItem.isUser ? 0 : Tokens.padding.large
                             
                             // Let implicitWidth dictate width (with +8 buffer for layout engine) to stop short words from splitting line breaks
                             width: Math.min(maxBubbleWidth, bubbleLayout.implicitWidth + Tokens.padding.medium * 2 + 8)
                             height: bubbleLayout.implicitHeight + Tokens.padding.medium * 2
                             radius: Tokens.rounding.large
                             color: delegateItem.isUser ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainer

                             // Asymmetric corners
                             topLeftRadius: Tokens.rounding.large
                             topRightRadius: Tokens.rounding.large
                             bottomLeftRadius: delegateItem.isUser ? Tokens.rounding.large : 4
                             bottomRightRadius: delegateItem.isUser ? 4 : Tokens.rounding.large
                             
                             Column {
                                 id: bubbleLayout
                                 anchors.top: parent.top
                                 anchors.topMargin: Tokens.padding.medium
                                 anchors.horizontalCenter: parent.horizontalCenter
                                 spacing: Tokens.spacing.small

                                 property string delegateThought: delegateItem.thoughtText
                                 property bool isExpanded: false

                                 Item {
                                     visible: bubbleLayout.delegateThought !== ""
                                     implicitWidth: thoughtRow.implicitWidth
                                     implicitHeight: thoughtRow.implicitHeight
                                     height: visible ? implicitHeight : 0

                                     Row {
                                         id: thoughtRow
                                         spacing: Tokens.spacing.small
                                         Text {
                                             text: "Thought Process"
                                             color: Colours.palette.m3onSurfaceVariant
                                             font: Tokens.font.body.small
                                         }
                                         MaterialIcon {
                                             id: thoughtArrow
                                             text: "expand_more"
                                             color: Colours.palette.m3onSurfaceVariant
                                             font: Tokens.font.icon.small
                                             rotation: bubbleLayout.isExpanded ? 180 : 0
                                             Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                         }
                                     }
                                     MouseArea {
                                         anchors.fill: parent
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: bubbleLayout.isExpanded = !bubbleLayout.isExpanded
                                     }
                                 }

                                 Item {
                                     id: thoughtContentWrapper
                                     width: thoughtContent.width
                                     height: bubbleLayout.isExpanded ? thoughtContent.implicitHeight : 0
                                     clip: true
                                     
                                     Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                                     TextEdit {
                                         id: thoughtContent
                                         width: Math.min(implicitWidth, bubbleRect.maxBubbleWidth - Tokens.padding.medium * 2)
                                         textFormat: Text.MarkdownText
                                         
                                         property string fullThought: bubbleLayout.delegateThought
                                         
                                         property bool cursorVisible: true
                                         Timer {
                                             running: !delegateItem.isFinished
                                             repeat: true
                                             interval: 400
                                             onTriggered: thoughtContent.cursorVisible = !thoughtContent.cursorVisible
                                         }
                                         
                                         text: delegateItem.isFinished ? fullThought : fullThought + (cursorVisible ? "▌" : "")
                                         
                                         color: Colours.palette.m3onSurfaceVariant
                                         font: Tokens.font.body.small
                                         wrapMode: Text.Wrap
                                         readOnly: true
                                         selectByMouse: true
                                         selectionColor: Colours.palette.m3primary
                                         selectedTextColor: Colours.palette.m3onPrimary
                                         opacity: bubbleLayout.isExpanded ? 1.0 : 0.0
                                         
                                         Behavior on opacity {
                                             SequentialAnimation {
                                                 PauseAnimation { duration: bubbleLayout.isExpanded ? 100 : 0 }
                                                 NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                             }
                                         }
                                     }
                                 }

                                 TextEdit {
                                     id: messageText
                                     textFormat: Text.MarkdownText
                                     width: Math.min(implicitWidth, bubbleRect.maxBubbleWidth - Tokens.padding.medium * 2)
                                     
                                     property string fullText: delegateItem.text !== undefined ? delegateItem.text : ""
                                     
                                     property bool cursorVisible: true
                                     Timer {
                                         running: !delegateItem.isFinished
                                         repeat: true
                                         interval: 400
                                         onTriggered: messageText.cursorVisible = !messageText.cursorVisible
                                     }
                                     
                                     text: delegateItem.isFinished ? fullText : fullText + (cursorVisible ? "▌" : "")
                                     
                                     color: delegateItem.isUser ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                     font: Tokens.font.body.small
                                     wrapMode: Text.Wrap
                                     readOnly: true
                                     selectByMouse: true
                                     selectionColor: Colours.palette.m3primary
                                     selectedTextColor: Colours.palette.m3onPrimary

                                     MouseArea {
                                         anchors.fill: parent
                                         hoverEnabled: true
                                         cursorShape: Qt.IBeamCursor
                                         propagateComposedEvents: true
                                         onPressed: mouse => mouse.accepted = false
                                     }
                                 }
                             }
                         }
                     }
                 }

                 // Input Box Row
                 StyledRect {
                     id: inputBoxRow
                     anchors.bottom: parent.bottom
                     anchors.left: parent.left
                     anchors.right: parent.right
                     z: 10
                     implicitHeight: Math.max(48, inputArea.implicitHeight + Tokens.padding.medium * 2)
                     color: Colours.tPalette.m3surfaceContainer
                     radius: 24

                     StyledClippingRect {
                         z: -1
                         anchors.fill: parent
                         radius: 24
                         ShaderEffectSource {
                             id: inputBlurSource
                             sourceItem: contentStack
                             sourceRect: {
                                 var p = parent.mapToItem(contentStack, 0, 0);
                                 return Qt.rect(p.x, p.y, parent.width, parent.height);
                             }
                         }
                         MultiEffect {
                             anchors.fill: parent
                             source: inputBlurSource
                             blurEnabled: true
                             blurMax: 32
                         }
                     }

                     StateLayer {
                         id: inputStateLayer
                         anchors.fill: parent
                         radius: 24
                         hoverEnabled: false
                         cursorShape: Qt.IBeamCursor
                         onClicked: inputArea.forceActiveFocus()
                     }

                     RowLayout {
                         anchors.fill: parent
                         anchors.leftMargin: Tokens.padding.large
                         anchors.rightMargin: Tokens.padding.small
                         spacing: Tokens.spacing.small


                          // Provider / model selector chip
                          StyledRect {
                              id: providerChip
                              Layout.alignment: Qt.AlignVCenter
                              Layout.preferredHeight: 32
                              implicitWidth: chipMinimized ? 32 : chipLayout.implicitWidth + Tokens.padding.medium * 2
                              radius: height / 2
                              color: selectorOpen ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                              Behavior on color { CAnim {} }
                              Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                              StateLayer {
                                  radius: parent.height / 2
                                  onClicked: selectorOpen = !selectorOpen
                              }

                              Row {
                                  id: chipLayout
                                  anchors.centerIn: parent
                                  spacing: Tokens.spacing.extraSmall

                                  MaterialIcon {
                                      anchors.verticalCenter: parent.verticalCenter
                                      text: root.activeProviderIcon
                                      color: root.selectorOpen ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                      font: Tokens.font.icon.small
                                  }

                                  StyledText {
                                      anchors.verticalCenter: parent.verticalCenter
                                      text: root.currentModel
                                      color: root.selectorOpen ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                      font: Tokens.font.body.small
                                      width: Math.min(implicitWidth, 140)
                                      elide: Text.ElideMiddle
                                      opacity: chipMinimized ? 0 : 1
                                      visible: opacity > 0.01

                                      Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                  }

                                  MaterialIcon {
                                      anchors.verticalCenter: parent.verticalCenter
                                      text: "expand_more"
                                      color: root.selectorOpen ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                      font: Tokens.font.icon.small
                                      rotation: root.selectorOpen ? 180 : 0
                                      opacity: chipMinimized ? 0 : 1
                                      visible: opacity > 0.01

                                      Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                      Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                  }
                              }
                          }
                         ScrollView {
                             id: inputScroll
                             Layout.fillWidth: true
                             Layout.fillHeight: true
                             
                             TextArea {
                                 id: inputArea
                                 verticalAlignment: TextInput.AlignVCenter
                                 placeholderText: qsTr("Ask assistant...")
                                 color: Colours.palette.m3onSurface
                                 placeholderTextColor: Colours.palette.m3outline
                                 font: Tokens.font.body.small
                                 wrapMode: Text.Wrap
                                 selectByMouse: true
                                 background: null

                                 MouseArea {
                                     anchors.fill: parent
                                     hoverEnabled: true
                                     cursorShape: Qt.IBeamCursor
                                     propagateComposedEvents: true
                                     onPressed: mouse => {
                                          var mapped = mapToItem(inputStateLayer, mouse.x, mouse.y);
                                          inputStateLayer.press(mapped.x, mapped.y);
                                          mouse.accepted = false;
                                      }
                                 }

                                 Keys.onPressed: event => {
                                     if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                                         event.accepted = true;
                                         root.sendPrompt(inputArea.text);
                                         inputArea.clear();
                                     }
                                 }
                             }
                         }

                         Item {
                             Layout.preferredWidth: 36
                             Layout.preferredHeight: 36

                             MaterialShape {
                                 anchors.fill: parent
                                 color: root.isTyping ? Colours.palette.m3error : (inputArea.text.length > 0 ? Colours.palette.m3primary : Colours.layer(Colours.tPalette.m3surfaceContainerHigh, 2))
                                 shape: root.isTyping ? MaterialShape.Cookie4Sided : MaterialShape.Arrow
                                 scale: sendMouse.pressed ? 0.6 : sendMouse.containsMouse ? 0.8 : 0.7
                                 rotation: 0
                                 
                                 Behavior on scale { Anim { type: Anim.FastSpatial } }
                                 Behavior on color { CAnim {} }

                                 MouseArea {
                                     id: sendMouse
                                     anchors.fill: parent
                                     hoverEnabled: true
                                     cursorShape: (inputArea.text.length > 0 || root.isTyping) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                     onClicked: {
                                         if (root.isTyping) {
                                             if (root.currentRequest) {
                                                 root.currentRequest.abort();
                                             }
                                             root.isTyping = false;
                                             root.isThinking = false;
                                             root.inAgentLoop = false;
                                             root.agentRounds = 0;
                                             typingTimer.stop();
                                             chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                                             saveHistory();
                                         } else if (inputArea.text.length > 0) {
                                             root.sendPrompt(inputArea.text);
                                             inputArea.clear();
                                         }
                                     }
                                 }
                             }

                         }
                     }
                 }
                  // Provider / model selector popup
                  MouseArea {
                      id: selectorScrim
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.bottom: inputBoxRow.top
                      z: 30
                      enabled: root.selectorOpen
                      visible: opacity > 0
                      opacity: root.selectorOpen ? 1 : 0

                      Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                      onClicked: root.selectorOpen = false

                      Elevation {
                          id: selectorPanel
                          radius: Tokens.rounding.large
                          level: 2

                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.bottom: parent.bottom
                          anchors.leftMargin: Tokens.spacing.small
                          anchors.rightMargin: Tokens.spacing.small
                          anchors.bottomMargin: Tokens.spacing.small

                          readonly property real maxListHeight: Math.max(120, selectorScrim.height * 0.6 - listChrome)
                          readonly property real listChrome: Tokens.padding.medium * 2 + (modelSearch.visible ? modelSearch.height + Tokens.spacing.small : 0) + Tokens.padding.large

                          implicitHeight: Math.min((modelSearch.visible ? modelSearch.height + selectorCol.spacing : 0) + Math.min(sectionsCol.implicitHeight, selectorPanel.maxListHeight) + Tokens.padding.small * 2, selectorScrim.height * 0.7)

                          transform: Scale {
                              yScale: root.selectorOpen ? 1 : 0.85
                              origin.y: selectorPanel.height

                              Behavior on yScale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                          }

                          MouseArea {
                              anchors.fill: parent
                              hoverEnabled: true
                              onWheel: e => e.accepted = true
                          }

                          StyledRect {
                              anchors.fill: parent
                              radius: parent.radius
                              color: Colours.palette.m3surfaceContainerLow
                          }

                          ColumnLayout {
                              id: selectorCol
                              anchors.fill: parent
                              anchors.margins: Tokens.padding.small
                              clip: true
                              spacing: Tokens.spacing.small


                              SearchBar {
                                  id: modelSearch
                                  Layout.fillWidth: true
                                  visible: root.totalModelCount > 8
                                  placeholderText: qsTr("Search models...")
                                  font: Tokens.font.body.small
                                  onTextEdited: searchDebounce.restart()
                              }

                              Flickable {
                                  id: sectionsScroll
                                  Layout.fillWidth: true
                                  implicitHeight: Math.min(sectionsCol.implicitHeight, selectorPanel.maxListHeight)
                                  clip: true
                                  boundsBehavior: Flickable.StopAtBounds
                                  contentWidth: width
                                  contentHeight: sectionsCol.implicitHeight

                                  ColumnLayout {
                                      id: sectionsCol
                                      width: sectionsScroll.width
                                      spacing: Tokens.spacing.extraSmall

                                      Repeater {
                                          model: root.visibleSections

                                          delegate: ColumnLayout {
                                              id: sectionItem

                                              required property var modelData
                                              readonly property bool expanded: root.isSectionExpanded(modelData)
                                              readonly property var rows: modelData.models
                                              readonly property bool isActiveSection: modelData.id === root.activeProvider
                                              visible: root.modelQuery.length === 0 || rows.length > 0

                                              Layout.fillWidth: true
                                              spacing: 0

                                              Item {
                                                  id: sectionHeader
                                                  Layout.fillWidth: true
                                                  implicitHeight: 32

                                                  StateLayer {
                                                      radius: Tokens.rounding.small
                                                      onClicked: root.toggleSection(sectionItem.modelData.id)
                                                  }

                                                  RowLayout {
                                                      anchors.fill: parent
                                                      anchors.leftMargin: Tokens.padding.small
                                                      anchors.rightMargin: Tokens.padding.small
                                                      spacing: Tokens.spacing.small

                                                      MaterialIcon {
                                                          Layout.alignment: Qt.AlignVCenter
                                                          text: sectionItem.modelData.icon
                                                          color: sectionItem.isActiveSection ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                                          font: Tokens.font.icon.small
                                                      }

                                                      StyledText {
                                                          Layout.alignment: Qt.AlignVCenter
                                                          text: sectionItem.modelData.label
                                                          color: sectionItem.isActiveSection ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                                          font: Tokens.font.body.small
                                                      }

                                                      StyledText {
                                                          Layout.alignment: Qt.AlignVCenter
                                                          Layout.maximumWidth: sectionHeader.width * 0.5
                                                          visible: sectionItem.isActiveSection
                                                          text: root.currentModel
                                                          color: Colours.palette.m3onSurfaceVariant
                                                          font: Tokens.font.body.small
                                                          elide: Text.ElideMiddle
                                                      }

                                                      Item {
                                                          Layout.fillWidth: true
                                                          Layout.fillHeight: true
                                                      }

                                                      MaterialIcon {
                                                          Layout.alignment: Qt.AlignVCenter
                                                          text: "expand_more"
                                                          color: Colours.palette.m3onSurfaceVariant
                                                          font: Tokens.font.icon.small
                                                          rotation: sectionItem.expanded ? 180 : 0

                                                          Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                                      }
                                                  }
                                              }

                                              Item {
                                                  Layout.fillWidth: true
                                                  implicitHeight: sectionItem.expanded ? rowsCol.implicitHeight : 0
                                                  clip: true
                                                  visible: implicitHeight > 0
                                                  opacity: sectionItem.expanded ? 1 : 0

                                                  Behavior on implicitHeight { enabled: sectionItem.rows.length < 100; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                                  Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                                                  ColumnLayout {
                                                      id: rowsCol
                                                      width: parent.width
                                                      spacing: 2

                                                      Repeater {
                                                          model: sectionItem.expanded ? sectionItem.rows : 0

                                                          delegate: StyledRect {
                                                              id: modelOption

                                                              required property var modelData
                                                              readonly property bool optionActive: modelData.name === root.currentModel && modelData.providerId === root.activeProvider

                                                              Layout.fillWidth: true
                                                              implicitHeight: 32
                                                              radius: optionActive ? Tokens.rounding.medium : Tokens.rounding.extraSmall
                                                              color: Qt.alpha(Colours.palette.m3tertiaryContainer, optionActive ? 1 : 0)

                                                              StateLayer {
                                                                  radius: parent.radius
                                                                  color: modelOption.optionActive ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                                                                  onClicked: {
                                                                      root.setActiveModel(modelOption.modelData.providerId, modelOption.modelData.name);
                                                                      root.selectorOpen = false;
                                                                  }
                                                              }

                                                              MaterialIcon {
                                                                  anchors.verticalCenter: parent.verticalCenter
                                                                  anchors.left: parent.left
                                                                  anchors.leftMargin: Tokens.padding.small
                                                                  visible: sectionItem.modelData.id === "recent"
                                                                  text: root.providerIconForId(modelOption.modelData.providerId)
                                                                  color: modelOption.optionActive ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                                                  font: Tokens.font.icon.small
                                                              }

                                                              StyledText {
                                                                  anchors.verticalCenter: parent.verticalCenter
                                                                  anchors.left: parent.left
                                                                  anchors.right: parent.right
                                                                  anchors.leftMargin: sectionItem.modelData.id === "recent" ? Tokens.padding.medium + 20 : Tokens.padding.medium
                                                                  anchors.rightMargin: Tokens.padding.small
                                                                  verticalAlignment: Text.AlignVCenter
                                                                  text: modelOption.modelData.name
                                                                  color: modelOption.optionActive ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                                                                  font: Tokens.font.body.small
                                                                  elide: Text.ElideMiddle
                                                              }
                                                          }
                                                      }
                                                  }
                                              }
                                          }
                                      }
                                  }
                              }

                              Row {
                                  id: statusLoading
                                  Layout.alignment: Qt.AlignHCenter
                                  visible: root.modelsLoading && root.totalModelCount === 0
                                  spacing: Tokens.spacing.small

                                  LoadingIndicator {
                                      width: 16
                                      height: 16
                                      color: Colours.palette.m3primary
                                  }

                                  StyledText {
                                      anchors.verticalCenter: parent.verticalCenter
                                      text: qsTr("Loading models...")
                                      color: Colours.palette.m3onSurfaceVariant
                                      font: Tokens.font.body.small
                                  }
                              }

                              StyledText {
                                  id: statusEmpty
                                  Layout.alignment: Qt.AlignHCenter
                                  visible: root.searchResultCount === 0 && root.modelQuery.length > 0 && !root.modelsLoading
                                  text: qsTr("No models found")
                                  color: Colours.palette.m3onSurfaceVariant
                                  font: Tokens.font.body.small
                              }
                          }
                      }
                  }

             }

             // History Grid View
             Item {
                 anchors.fill: parent
                 opacity: isHistoryTab ? 1 : 0
                 visible: opacity > 0
                 Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                 GridView {
                     anchors.top: parent.top
                     anchors.left: parent.left
                     anchors.right: parent.right
                     anchors.bottom: newChatButton.top
                     anchors.bottomMargin: Tokens.spacing.medium
                     
                     cellWidth: width / 2
                     cellHeight: 90
                     model: historySessionsModel

                     delegate: Item {
                         required property var model
                         property string chatId: model && model.id ? String(model.id) : ""
                         property string chatTitle: model && model.title ? String(model.title) : ""
                         property string chatPreview: model && model.preview ? String(model.preview) : ""
                         property string chatUpdated: model && model.updated ? String(model.updated) : ""
                         property string chatIcon: model && model.providerIcon ? String(model.providerIcon) : "chat"

                         width: GridView.view.cellWidth
                         height: GridView.view.cellHeight

                         StyledRect {
                             anchors.fill: parent
                             anchors.margins: Tokens.spacing.small
                             radius: Tokens.rounding.medium
                             color: Colours.tPalette.m3surfaceContainerHigh

                             StateLayer {
                                 radius: Tokens.rounding.medium
                                 onClicked: loadChat(chatId)
                             }

                             RowLayout {
                                 anchors.fill: parent
                                 anchors.margins: Tokens.padding.small
                                 spacing: Tokens.spacing.medium

                                 StyledRect {
                                     Layout.preferredWidth: 32
                                     Layout.preferredHeight: 32
                                     radius: 16
                                     color: Colours.tPalette.m3surfaceContainerHighest

                                     MaterialIcon {
                                         anchors.centerIn: parent
                                         text: chatIcon
                                         color: Colours.palette.m3onSurfaceVariant
                                         font: Tokens.font.icon.small
                                     }
                                 }

                                 ColumnLayout {
                                     Layout.fillWidth: true
                                     spacing: 2
                                 
                                     Text {
                                         Layout.fillWidth: true
                                         text: chatTitle ? chatTitle : "New Chat"
                                         color: Colours.palette.m3onSurface
                                         font: Tokens.font.label.small
                                         elide: Text.ElideRight
                                     }
                                 
                                     Text {
                                         Layout.fillWidth: true
                                         visible: chatPreview !== ""
                                         text: chatPreview
                                         color: Colours.palette.m3onSurfaceVariant
                                         font: Tokens.font.body.small
                                         elide: Text.ElideRight
                                         maximumLineCount: 1
                                     }
                                 
                                     Text {
                                         Layout.fillWidth: true
                                         visible: chatUpdated !== ""
                                         text: chatUpdated
                                         color: Colours.palette.m3onSurfaceVariant
                                         font: Tokens.font.label.small
                                         elide: Text.ElideRight
                                     }
                                }

                                 Item {
                                     Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                     Layout.preferredWidth: 24
                                     Layout.preferredHeight: 24
                                     
                                     StyledRect {
                                         anchors.fill: parent
                                         radius: 12
                                         color: Colours.palette.m3onSurfaceVariant
                                         opacity: deleteMouseArea.containsMouse ? 0.12 : 0.0
                                         Behavior on opacity { NumberAnimation { duration: 150 } }
                                     }

                                     MaterialIcon {
                                         anchors.centerIn: parent
                                         text: "close"
                                         font: Tokens.font.icon.small
                                         color: Colours.palette.m3onSurfaceVariant
                                     }

                                     MouseArea {
                                         id: deleteMouseArea
                                         anchors.fill: parent
                                         hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: deleteChat(chatId)
                                     }
                                 }
                             }
                         }
                     }
                 }

                 // "Clear All" button
                 StyledRect {
                     id: clearAllButton
                     anchors.bottom: parent.bottom
                     anchors.left: parent.left
                     width: clearAllLayout.implicitWidth + Tokens.padding.large * 2
                     height: 32
                     radius: 16
                     color: Colours.palette.m3errorContainer

                     StateLayer {
                         radius: 16
                         onClicked: clearAllHistory()
                     }

                     RowLayout {
                         id: clearAllLayout
                         anchors.centerIn: parent
                         spacing: Tokens.spacing.small
                         MaterialIcon {
                             text: "delete"
                             color: Colours.palette.m3onErrorContainer
                             font: Tokens.font.icon.small
                         }
                         Text {
                             text: "Clear All"
                             color: Colours.palette.m3onErrorContainer
                             font: Tokens.font.body.small
                         }
                     }
                 }

                 // "New Chat" button
                 StyledRect {
                     id: newChatButton
                     anchors.bottom: parent.bottom
                     anchors.right: parent.right
                     width: newChatLayout.implicitWidth + Tokens.padding.large * 2
                     height: 32
                     radius: 16
                     color: Colours.palette.m3primaryContainer

                     StateLayer {
                         radius: 16
                         onClicked: createNewChat()
                     }

                     RowLayout {
                         id: newChatLayout
                         anchors.centerIn: parent
                         spacing: Tokens.spacing.small
                         MaterialIcon {
                             text: "add"
                             color: Colours.palette.m3onPrimaryContainer
                             font: Tokens.font.icon.small
                         }
                         Text {
                             text: "New Chat"
                             color: Colours.palette.m3onPrimaryContainer
                             font: Tokens.font.body.small
                         }
                     }
                 }
             }
         }
    }
}