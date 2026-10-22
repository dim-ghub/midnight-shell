"""Smoke-test the preview page with a fake checker and lightweight theme/layout controls.

Run after building caelestia-i18n: python tests/test_update_preview_ui.py.
This checks QML loading, 200 result rows, and page overflow; it does not validate
upstream theme rendering or execute a real package-manager query.
"""
from pathlib import Path
import tempfile,subprocess,os,json

def main():
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as d:
     root=Path(d)
     source=(repo/'modules/nexus/pages/UpdatesPage.qml').read_text()
     source='\n'.join(line for line in source.splitlines() if not line.startswith('import qs.'))
     (root/'UpdatesPage.qml').write_text(source)
     (root/'qmldir').write_text('singleton Colours 1.0 Colours.qml\nUpdatesPage 1.0 UpdatesPage.qml\nPageBase 1.0 PageBase.qml\nStyledText 1.0 StyledText.qml\nStyledRect 1.0 StyledRect.qml\nIconTextButton 1.0 IconTextButton.qml\n')
     (root/'Colours.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var palette: ({m3outline:"gray",m3error:"red"}); property var tPalette: ({m3surfaceContainer:"#303030"}) }')
     (root/'StyledText.qml').write_text('import QtQuick\nText { textFormat: Text.PlainText; color: "white" }')
     (root/'StyledRect.qml').write_text('import QtQuick\nRectangle {}')
     (root/'IconTextButton.qml').write_text('import QtQuick\nItem { property string icon; property string text; signal clicked(); implicitHeight: 40; implicitWidth: 140 }')
     (root/'PageBase.qml').write_text('''import QtQuick
    Item {
     id: root
     property string title
     default property Item contentChild
     property alias flickable: scroll
     readonly property int cappedWidth: width
     Flickable {
     id: scroll; anchors.fill: parent; clip: true
     contentHeight: root.contentChild ? root.contentChild.implicitHeight : 0
     contentItem.children: [root.contentChild]
     }
    }''')
     scripts=root/'assets/scripts';scripts.mkdir(parents=True)
     (scripts/'list_updates.py').write_text('import json; print(json.dumps('+repr(dict(packages=[dict(name='package-'+str(i),current='1.0',new='2.0',source='Repository',icon='package-x-generic') for i in range(200)],errors=[]))+'))')
     (root/'shell.qml').write_text('''import QtQuick
    import Quickshell
    ShellRoot {
     FloatingWindow {
     implicitWidth: 640; implicitHeight: 360
     UpdatesPage { id: preview; anchors.fill: parent }
     Timer { interval: 100; running: true; repeat: true; onTriggered: {
     if (!preview.checkedOnce) return;
     if (preview.packages.length !== 200 || preview.errorText.length) throw new Error("Preview failed: " + preview.errorText);
     if (preview.flickable.contentHeight <= preview.flickable.height) throw new Error("Missing page overflow");
     preview.flickable.contentY = preview.flickable.contentHeight - preview.flickable.height;
     console.log("UPDATE_PREVIEW_UI_PASS",preview.packages.length,preview.flickable.contentY);
     Qt.quit();
     } }
     }
    }''')
     env=os.environ.copy();env.pop('WAYLAND_DISPLAY',None)
     env.update(QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_CONFIG_HOME=str(root/'config'),QML_IMPORT_PATH=str(repo/'build/qml'))
     r=subprocess.run(['qs','-p',str(root/'shell.qml')],env=env,capture_output=True,text=True,timeout=15)
     print(r.stdout+r.stderr)
     assert r.returncode==0 and 'UPDATE_PREVIEW_UI_PASS' in r.stdout+r.stderr

if __name__ == "__main__":
    main()
