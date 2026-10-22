"""Prepare metadata and the pinned VS2022 media dependency for Windows releases."""
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from build_metadata import generate, published_build_floor


def main():
    defines, manifest = generate(datetime.now(timezone.utc), run_number=int(os.environ['GITHUB_RUN_NUMBER']),
        run_attempt=int(os.environ['GITHUB_RUN_ATTEMPT']), minimum_build=published_build_floor())
    manifest['platforms'] = ['windows']
    Path('build_metadata.json').write_text(json.dumps(defines), encoding='utf-8')
    Path('versions.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    from prepare_windows_mdk import prepare
    prepare()


if __name__ == '__main__':
    main()
