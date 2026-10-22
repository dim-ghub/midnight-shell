#!/usr/bin/env python3
"""Exercise the component's actual clock in Quickshell, with simulated bars."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = (ROOT / 'modules/background/Visualiser.qml').read_text()
    start = source.index('                Timer {')
    end = source.index('{', start) + 1
    depth = 1
    while depth:
        if source[end] == '{':
            depth += 1
        elif source[end] == '}':
            depth -= 1
        end += 1
    # Only replace a wall-clock dependency if the implementation still uses it.
    clock = source[start:end].replace('Date.now()', 'root.testWallTime()')
    qml = '''import QtQuick
import Quickshell
ShellRoot {
    id: root
    property real opacity: 1
    property bool rendererGpu: false
    property double wallClockOffset: 0
    property int pausedFrames: -1
    function testWallTime() { return Date.now() + wallClockOffset; }
    function check(condition, message) {
        if (!condition) { console.error("VISUALISER_TEST_FAIL: " + message); Qt.exit(1); }
    }
    QtObject {
        id: bars
        property bool settled: false
        property int frames: 0
        property bool validDelta: true
        function advance(delta) {
            frames++;
            validDelta = validDelta && delta > 0 && delta <= 0.1;
        }
    }
    QtObject {
        id: dataCanvas
        property int uploads: 0
        function requestPaint() { uploads++; }
    }
    CLOCK
    Timer {
        interval: 100
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            step++;
            if (step === 6) {
                root.check(bars.frames >= 5 && bars.frames <= 25, "clock stays near 30 fps");
                root.check(bars.validDelta, "positive bounded frame deltas");
                root.check(dataCanvas.uploads === 0, "CPU renderer must not upload textures");
                root.wallClockOffset = -60000;
            } else if (step === 7) {
                root.wallClockOffset = 0;
                root.check(bars.validDelta, "clock changes must not produce negative deltas");
                root.rendererGpu = true;
            } else if (step === 9) {
                root.check(dataCanvas.uploads > 0, "GPU receives data updates");
                root.opacity = 0;
                root.pausedFrames = bars.frames;
            } else if (step === 10) {
                root.check(bars.frames === root.pausedFrames, "hidden visualiser stops advancing");
                console.log("VISUALISER_TEST_PASS");
                Qt.quit();
            }
        }
    }
}
'''.replace('CLOCK', clock)
    runner = shutil.which('qs')
    if not runner:
        raise RuntimeError('Quickshell is required')
    with tempfile.TemporaryDirectory() as directory:
        fixture = Path(directory) / 'shell.qml'
        fixture.write_text(qml)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        env.pop('WAYLAND_DISPLAY', None)
        result = subprocess.run([runner, '-p', str(fixture)], env=env, capture_output=True, text=True, timeout=20)
        log = result.stdout + result.stderr
        print(log, end='')
        return 0 if result.returncode == 0 and 'VISUALISER_TEST_PASS' in log and 'VISUALISER_TEST_FAIL' not in log else 1


if __name__ == '__main__':
    raise SystemExit(main())
