import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest

from prepare_release_assets import main


class ReleaseAssetsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.temporary.name)
        source = Path('release/nested')
        source.mkdir(parents=True)
        Path('release/versions.json').write_text(json.dumps({'release_tag': 'test'}))
        for suffix in ['.apk', '-tv.apk', '.ipa', '-apple-tv.ipa', '-macos.zip',
                       '-windows.zip', '-windows-portable.zip', '-linux-x64.tar.gz', '-linux-amd64.deb',
                       '-linux-x86_64.rpm', '-linux-x86_64.AppImage']:
            (source / ('easyTV-test' + suffix)).write_bytes(b'x' * 1024)

    def tearDown(self):
        os.chdir(self.previous)
        self.temporary.cleanup()

    def test_all_platforms_are_flattened_and_checksummed(self):
        main()
        lines = Path('release-assets/SHA256SUMS').read_text().splitlines()
        self.assertEqual(len(lines), 12)
        for line in lines:
            digest, name = line.split('  ', 1)
            self.assertEqual(hashlib.sha256((Path('release-assets') / name).read_bytes()).hexdigest(), digest)

    def test_missing_platform_prevents_release(self):
        Path('release/nested/easyTV-test.ipa').unlink()
        with self.assertRaises(ValueError):
            main()

    def test_duplicate_platform_prevents_release(self):
        Path('release/easyTV-test.apk').write_bytes(b'x' * 1024)
        with self.assertRaises(ValueError):
            main()


if __name__ == '__main__':
    unittest.main()
