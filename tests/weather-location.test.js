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

test('city search ignores stale responses and reports request failures', () => {
    const requests = [];
    const search = loadMethods('services/LocationSearch.qml', ['search', 'clear'], {
        generation: 0, results: [], loading: false, errorText: '',
        Tr: { tr: value => value },
        GlobalConfig: { general: { language: 'es' } },
        Qt: { locale: () => ({ name: 'es_CL' }) },
        Requests: { get(...args) { requests.push(args); } }
    });
    search.root = search;
    search.search('a');
    assert.equal(requests.length, 0);
    search.search('Santiago');
    search.search('Valparaíso');
    requests[0][1](JSON.stringify({ results: [{ name: 'stale', latitude: 1, longitude: 2 }] }));
    assert.equal(search.results.length, 0);
    assert.match(requests[1][0], /Valpara%C3%ADso/);
    requests[1][1](JSON.stringify({ results: [{ name: 'Valparaíso', latitude: -33, longitude: -71 }] }));
    assert.equal(search.results[0].name, 'Valparaíso');
    assert.equal(search.loading, false);
    search.search('Santiago');
    requests[2][2]('offline');
    assert.equal(search.loading, false);
    assert.match(search.errorText, /connection/);
});

test('weather selections save coordinates and automatic mode clears the override', () => {
    let saves = 0;
    const weather = loadMethods('services/Weather.qml', ['setLocation', 'useAutomaticLocation'], {
        loc: 'old', city: 'old',
        GlobalConfig: { services: { weatherLocation: 'old' }, save() { saves++; } },
        cacheCity() {}, reload() {}
    });
    weather.setLocation(-33.45, -70.64, 'Santiago');
    assert.equal(weather.GlobalConfig.services.weatherLocation, '-33.45,-70.64');
    assert.equal(weather.city, 'Santiago');
    weather.setLocation(100, 20, 'invalid');
    assert.equal(saves, 1);
    weather.useAutomaticLocation();
    assert.equal(weather.GlobalConfig.services.weatherLocation, '');
    assert.equal(weather.loc, '');
    assert.equal(saves, 2);
});


test('city search rejects malformed responses and clearing invalidates pending callbacks', () => {
    const requests = [];
    const search = loadMethods('services/LocationSearch.qml', ['search', 'clear'], {
        generation: 0, results: [], loading: false, errorText: '',
        Tr: { tr: value => value },
        GlobalConfig: { general: { language: '' } },
        Qt: { locale: () => ({ name: 'es_CL' }) },
        Requests: { get(...args) { requests.push(args); } }
    });
    search.root = search;
    search.search('Santiago');
    assert.match(requests[0][0], /language=es/);
    requests[0][1]('{broken');
    assert.match(search.errorText, /invalid response/);
    assert.equal(search.loading, false);
    search.search('Santiago');
    requests[1][1](JSON.stringify({ results: [null, { name: 'bad', latitude: 95, longitude: 0 }] }));
    assert.equal(search.results.length, 0);
    assert.match(search.errorText, /No matching/);
    search.search('Santiago');
    search.clear();
    requests[2][1](JSON.stringify({ results: [{ name: 'late', latitude: 0, longitude: 0 }] }));
    requests[2][2]('late error');
    assert.equal(search.results.length, 0);
    assert.equal(search.errorText, '');
    assert.equal(search.loading, false);
});
