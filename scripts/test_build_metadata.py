import unittest
import io
import json
from unittest.mock import patch
from datetime import datetime, timezone

from build_metadata import generate, published_build_floor


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

    def test_new_workflow_counter_cannot_go_backwards(self):
        now = datetime(2026, 10, 22, tzinfo=timezone.utc)
        _, manifest = generate(now, run_number=1, minimum_build=12000401)
        self.assertEqual(manifest['latest_build'], 12000402)

    def test_floor_includes_non_latest_releases_and_drafts(self):
        releases = [{'tag_name': '2.9.9-20261022-12000401'},
                    {'tag_name': '2.9.9-20261023-12000555', 'draft': True},
                    {'tag_name': 'other-project-99999999'}]
        with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true', 'GH_TOKEN': 'test', 'GITHUB_REPOSITORY': 'owner/repo'}):
            with patch('build_metadata.urlopen', return_value=io.StringIO(json.dumps(releases))):
                self.assertEqual(published_build_floor(), 12000555)

    def test_floor_errors_do_not_silently_allocate_an_old_number(self):
        with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true', 'GH_TOKEN': 'test', 'GITHUB_REPOSITORY': 'owner/repo'}):
            with patch('build_metadata.urlopen', side_effect=OSError('unavailable')):
                with self.assertRaises(OSError):
                    published_build_floor()


if __name__ == '__main__':
    unittest.main()
