import importlib.util, subprocess, unittest
from unittest.mock import patch
from pathlib import Path
spec = importlib.util.spec_from_file_location('updates', str(Path(__file__).resolve().parents[1] / 'assets/scripts/list_updates.py'))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class UpdatesTest(unittest.TestCase):

    @patch.object(mod.shutil, 'which', return_value='/usr/bin/tool')
    def test_preview(self, _):
        with patch.object(mod.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'quickshell 0.1-1 -> 0.2-1\n', '')) as run:
            rows, error = mod.query('Repository', ['checkupdates', '--nocolor'])
            self.assertEqual(rows[0]['new'], '0.2-1')
            self.assertFalse(error)
            self.assertEqual(run.call_args.args[0], ['checkupdates', '--nocolor'])

    @patch.object(mod.shutil, 'which', return_value='/usr/bin/tool')
    def test_no_updates(self, _):
        with patch.object(mod.subprocess, 'run', return_value=subprocess.CompletedProcess([], 2, '', '')):
            self.assertEqual(mod.query('Repository', ['checkupdates']), ([], ''))

    @patch.object(mod.shutil, 'which', return_value='/usr/bin/tool')
    def test_network_error(self, _):
        with patch.object(mod.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'network error')):
            self.assertIn('network error', mod.query('AUR', ['paru', '-Qua'])[1])

    @patch.object(mod.shutil, 'which', return_value='/usr/bin/tool')
    def test_timeout(self, _):
        with patch.object(mod.subprocess, 'run', side_effect=subprocess.TimeoutExpired('checkupdates', 90)):
            self.assertTrue(mod.query('Repository', ['checkupdates'])[1])

    def test_package_icons(self):
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as folder:
            apps = Path(folder) / 'applications'
            apps.mkdir()
            desktop = apps / 'code.desktop'
            desktop.write_text('[Desktop Entry]\nName=VS Code\nIcon=vscode\nExec=code %F\n')
            rows = [{'name': 'visual-studio-code-bin'}, {'name': 'library'}]
            with patch.object(mod.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, f'visual-studio-code-bin {desktop}\n', '')):
                mod.add_icons(rows)
            self.assertEqual(rows[0]['icon'], 'vscode')
            self.assertEqual(rows[1]['icon'], 'package-x-generic')

    @patch.object(mod.shutil, 'which', return_value='/usr/bin/paru')
    def test_aur_up_to_date(self, _):
        with patch.object(mod.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', '')):
            self.assertEqual(mod.query('AUR', ['paru', '-Qua']), ([], ''))

    @patch.object(mod.shutil, 'which', return_value='/usr/bin/paru')
    def test_aur_error_preserved(self, _):
        with patch.object(mod.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'network unavailable')):
            self.assertIn('network unavailable', mod.query('AUR', ['paru', '-Qua'])[1])
if __name__ == '__main__':
    unittest.main()
