import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile
from windows_archives import create_archives


class WindowsArchivesTest(unittest.TestCase):
    def test_both_variants_exclude_personal_data_and_nested_archives(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / 'bundle'
            for name in ('easy_tv_live.exe', 'flutter_windows.dll', 'data/app.so',
                         'user_data/shared_preferences.json', 'portable.flag', 'old.zip', '便携版使用说明.txt'):
                file = bundle / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(b'fixture')
            normal, portable = create_archives(bundle, root / 'packages', 'test')
            for archive in (normal, portable):
                with ZipFile(archive) as stream:
                    self.assertIsNone(stream.testzip())
                    self.assertEqual(len(stream.namelist()), len(set(stream.namelist())))
                    self.assertNotIn('user_data/shared_preferences.json', stream.namelist())
                    self.assertNotIn('old.zip', stream.namelist())
                    self.assertIn('data/app.so', stream.namelist())
                    self.assertEqual('portable.flag' in stream.namelist(), archive == portable)
            with ZipFile(portable) as stream:
                self.assertIn('user_data/', stream.namelist())

    def test_missing_runtime_prevents_packaging(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(ValueError):
                create_archives(Path(temporary) / 'missing', Path(temporary) / 'out', 'test')
