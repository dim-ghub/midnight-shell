#!/usr/bin/env python3
"""Check the real FileView/JsonAdapter preferences across fresh Quickshell runs."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def block(source, marker):
    start = source.index(marker)
    end = source.index('{', start) + 1
    depth = 1
    while depth:
        if source[end] == '{':
            depth += 1
        elif source[end] == '}':
            depth -= 1
        end += 1
    return source[start:end]


def main():
    source = (ROOT / 'services/Audio.qml').read_text()
    methods = '\n'.join(block(source, 'function ' + name + '(') for name in ('deviceKey', 'isDeviceHidden', 'toggleDeviceHidden'))
    store = block(source, 'FileView {')
    fixture = '''import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    id: root
    property alias hiddenDevices: devicePreferences.hiddenDevices
    property bool showHiddenDevices: false
    property var nodes: [{name: "shared", isSink: true, id: 1}, {name: "shared", isSink: false, id: 2}]
    property var visibleNodes: nodes.filter(node => showHiddenDevices || !isDeviceHidden(node))
    function check(value, message) {
        if (!value) { console.error("AUDIO_TEST_FAIL: " + message); Qt.exit(1); }
    }
    METHODS
    STORE
    Timer {
        interval: 100
        repeat: true
        running: true
        property int step: 0
        onTriggered: {
            step++;
            if (step === 2) {
                if (READ) root.check(root.isDeviceHidden(root.nodes[0]), "saved output restored on a fresh process");
                root.toggleDeviceHidden(root.nodes[0]);
            } else if (step === 4) {
                root.check(root.visibleNodes.length === (READ ? 2 : 1), "filter reacts to adapter changes");
                root.check(!root.isDeviceHidden(root.nodes[1]), "microphone with the same name stays visible");
                if (!READ) root.check(root.isDeviceHidden({name: "shared", isSink: true, id: 99}), "node ID is not persisted");
                root.showHiddenDevices = true;
            } else if (step === 5) {
                root.check(root.visibleNodes.length === 2, "show-hidden mode exposes both devices");
                console.log("AUDIO_TEST_PASS");
                Qt.quit();
            }
        }
    }
}
'''
    runner = shutil.which('qs')
    if not runner:
        raise RuntimeError('Quickshell is required')
    with tempfile.TemporaryDirectory() as directory:
        state = Path(directory) / 'state/audio-devices.json'
        store = store.replace('`${Paths.state}/audio-devices.json`', json.dumps(str(state)))
        for read in (False, True):
            path = Path(directory) / 'shell.qml'
            path.write_text(fixture.replace('METHODS', methods).replace('STORE', store).replace('READ', 'true' if read else 'false'))
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run([runner, '-p', str(path)], env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            print(output, end='')
            if result.returncode or 'AUDIO_TEST_PASS' not in output or 'AUDIO_TEST_FAIL' in output:
                return 1
            expected = [] if read else ['output:shared']
            if json.loads(state.read_text())['hiddenDevices'] != expected:
                return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
