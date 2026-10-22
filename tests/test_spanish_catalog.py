"""Check the rebuilt native catalog in an isolated offscreen Quickshell process.

Build caelestia-i18n first; this does not install libraries or change live settings.
"""
from pathlib import Path
import os
import subprocess
import tempfile


def main():
    repository = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as folder:
        source = Path(folder) / 'shell.qml'
        source.write_text('''import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
ShellRoot {
    Timer {
        interval: 50
        running: true
        onTriggered: {
            GlobalConfig.general.language = "es";
            if (!Tr.supportedLanguages.includes("es"))
                throw new Error("Spanish is not registered");
            if (Tr.tr("Language") !== "Idioma" || Tr.tr("Code editor") !== "Editor de Código")
                throw new Error("Spanish strings did not load");
            if (Tr.trN("%n notification", "%n notifications", 1) !== "1 notificación"
                || Tr.trN("%n notification", "%n notifications", 2) !== "2 notificaciones")
                throw new Error("Spanish plural forms failed");
            GlobalConfig.general.language = "en";
            if (Tr.tr("Language") !== "Language")
                throw new Error("Explicit English fell back to Spanish");
            console.log("SPANISH_CATALOG_TEST_PASS");
            Qt.quit();
        }
    }
}''')
        environment = os.environ.copy()
        environment.pop('WAYLAND_DISPLAY', None)
        environment.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                           LC_ALL='es_CL.UTF-8', XDG_CONFIG_HOME=folder,
                           QML_IMPORT_PATH=str(repository / 'build/qml'))
        result = subprocess.run(['qs', '-p', str(source)], env=environment,
                                capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        if result.returncode != 0 or 'SPANISH_CATALOG_TEST_PASS' not in output:
            raise SystemExit('Native Spanish catalog validation failed')


if __name__ == '__main__':
    main()
