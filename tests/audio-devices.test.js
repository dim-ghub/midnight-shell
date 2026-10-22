const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const repository = path.resolve(__dirname, '..');
const shell = fs.existsSync(path.join(repository, 'shell', 'services')) ? path.join(repository, 'shell') : repository;

function loadMethods(relative, names, context) {
    const source = fs.readFileSync(path.join(shell, relative), 'utf8');
    let code = '';
    for (const name of names) {
        const start = source.indexOf(`    function ${name}(`);
        assert.notEqual(start, -1, `Missing QML method ${name}`);
        const open = source.indexOf('{', start);
        let depth = 1, quote = null, escaped = false, end = open + 1;
        for (; depth > 0 && end < source.length; end++) {
            const ch = source[end];
            if (quote) {
                if (escaped) escaped = false;
                else if (ch === '\\') escaped = true;
                else if (ch === quote) quote = null;
            } else if ('"\'`'.includes(ch)) quote = ch;
            else if (ch === '{') depth++;
            else if (ch === '}') depth--;
        }
        code += source.slice(start, end).replace(/:\s*(?:string|bool|void|real|PwNode|var)\b/g, '') + '\n';
    }
    vm.createContext(context);
    vm.runInContext(code, context);
    return context;
}

test('audio hiding survives node ID changes and separates input/output names', () => {
    let writes = 0;
    const audio = loadMethods('services/Audio.qml', ['deviceKey', 'isDeviceHidden', 'toggleDeviceHidden'], {
        hiddenDevices: [], deviceStore: { writeAdapter() { writes++; } }
    });
    const output = { isSink: true, name: 'stable-name', id: 1 };
    const input = { isSink: false, name: 'stable-name', id: 2 };
    audio.toggleDeviceHidden(output);
    assert.equal(audio.isDeviceHidden({ ...output, id: 99 }), true);
    assert.equal(audio.isDeviceHidden(input), false);
    audio.toggleDeviceHidden(input);
    audio.toggleDeviceHidden(output);
    assert.equal(audio.isDeviceHidden(output), false);
    assert.equal(audio.isDeviceHidden(input), true);
    assert.equal(writes, 3);
});

test('cycling outputs skips hidden devices and tolerates all devices hidden', () => {
    const first = { name: 'first' }, second = { name: 'second' };
    let selected;
    const audio = loadMethods('services/Audio.qml', ['cycleNextAudioOutput'], {
        sinks: [first, second], sink: first,
        isDeviceHidden(node) { return node === first; }, setAudioSink(node) { selected = node; }
    });
    audio.cycleNextAudioOutput();
    assert.equal(selected, second);
    audio.isDeviceHidden = () => true;
    selected = undefined;
    audio.cycleNextAudioOutput();
    assert.equal(selected, undefined);
});


test('unnamed or missing audio nodes do not create persisted hidden entries', () => {
    let writes = 0;
    const audio = loadMethods('services/Audio.qml', ['deviceKey', 'isDeviceHidden', 'toggleDeviceHidden'], {
        hiddenDevices: [], deviceStore: { writeAdapter() { writes++; } }
    });
    audio.toggleDeviceHidden(null);
    audio.toggleDeviceHidden({ isSink: true, name: '' });
    assert.equal(writes, 0);
    assert.equal(audio.hiddenDevices.length, 0);
});
