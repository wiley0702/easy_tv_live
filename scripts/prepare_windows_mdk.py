"""Download the pinned, verified VS2022 media SDK without changing build metadata."""
import hashlib
import json
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname, urlretrieve


def prepare():
    config = Path('.dart_tool/package_config.json').resolve()
    packages = json.loads(config.read_text(encoding='utf-8'))['packages']
    package = next(item for item in packages if item['name'] == 'fvp')
    source = Path(url2pathname(urlparse(urljoin(config.as_uri(), package['rootUri'])).path))
    archive = source / 'windows/mdk-sdk-windows-x64.7z'
    urlretrieve('https://github.com/wang-bin/mdk-sdk/releases/download/v0.35.0/mdk-sdk-windows-desktop-vs2022-x64.7z', archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != '3a828b269817870ce00807d0f99f6caf72deb27a443b27fd50dc4f977fa1439a':
        raise ValueError('MDK SDK checksum mismatch')


if __name__ == '__main__':
    prepare()
