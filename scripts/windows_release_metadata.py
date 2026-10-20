"""Prepare metadata and the pinned VS2022 media dependency for Windows releases."""
import json
import hashlib
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname, urlretrieve


def main():
    day = datetime.now(timezone(timedelta(hours=8))).strftime('%Y-%m-%d')
    number = 11100000 + int(os.environ['GITHUB_RUN_NUMBER']) * 100 + int(os.environ['GITHUB_RUN_ATTEMPT'])
    tag = f"2.9.9-{day.replace('-', '')}-{number}"
    Path('build_metadata.json').write_text(json.dumps({'BUILD_DATE': day, 'BUILD_NUMBER': str(number)}), encoding='utf-8')
    Path('versions.json').write_text(json.dumps({
        'latest_version': '2.9.9', 'latest_build': number, 'build_date': day,
        'release_tag': tag, 'platforms': ['windows'],
        'update_log': ['移除内置源，支持逐源更新和删除', '添加和编辑网络源时可填写标题及 User-Agent'],
    }, ensure_ascii=False, indent=2), encoding='utf-8')
    config = Path('.dart_tool/package_config.json').resolve()
    packages = json.loads(config.read_text(encoding='utf-8'))['packages']
    package = next(item for item in packages if item['name'] == 'fvp')
    source = Path(url2pathname(urlparse(urljoin(config.as_uri(), package['rootUri'])).path))
    archive = source / 'windows/mdk-sdk-windows-x64.7z'
    # Pin the media SDK to a release built with VS2022, instead of nightly/VS2026.
    urlretrieve('https://github.com/wang-bin/mdk-sdk/releases/download/v0.35.0/mdk-sdk-windows-desktop-vs2022-x64.7z', archive)
    if archive.stat().st_size < 1000000 or archive.read_bytes()[:6] != bytes.fromhex('377abcaf271c'):
        raise ValueError('Invalid MDK SDK archive')
    if hashlib.sha256(archive.read_bytes()).hexdigest() != '3a828b269817870ce00807d0f99f6caf72deb27a443b27fd50dc4f977fa1439a':
        raise ValueError('MDK SDK checksum mismatch')


if __name__ == '__main__':
    main()
