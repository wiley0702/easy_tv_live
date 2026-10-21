import unittest
from datetime import datetime, timezone

from build_metadata import generate


class BuildMetadataTest(unittest.TestCase):
    def test_utc_plus_eight_date_and_monotonic_build(self):
        now = datetime(2026, 10, 20, 17, 0, 0, tzinfo=timezone.utc)
        defines, manifest = generate(now)
        self.assertEqual(defines['BUILD_DATE'], '2026-10-21')
        self.assertEqual(manifest['latest_version'], '2.9.9')
        self.assertGreater(manifest['latest_build'], 11100101)
        self.assertEqual(int(defines['BUILD_NUMBER']), manifest['latest_build'])
        self.assertLess(2000000000 + manifest['latest_build'], 2100000000)
        later = generate(now, run_number=2)[1]
        self.assertGreater(later['latest_build'], manifest['latest_build'])
        self.assertNotEqual(later['release_tag'], manifest['release_tag'])
        retry = generate(now, run_attempt=2)[1]
        self.assertGreater(retry['latest_build'], manifest['latest_build'])

    def test_tag_build_preserves_download_tag(self):
        _, manifest = generate(datetime(2026, 10, 20, tzinfo=timezone.utc), 'tag', '2.9.9-build1')
        self.assertEqual(manifest['release_tag'], '2.9.9-build1')


if __name__ == '__main__':
    unittest.main()
