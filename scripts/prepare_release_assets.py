"""Require every platform bundle before assembling public release attachments."""
import hashlib
import json
from pathlib import Path
import shutil


def main():
    source = Path('release')
    manifest_path = source / 'versions.json'
    metadata = json.loads(manifest_path.read_text(encoding='utf-8'))
    stem = f"easyTV-{metadata['release_tag']}"
    suffixes = ['.apk', '-tv.apk', '.ipa', '-apple-tv.ipa', '-macos.zip',
                '-windows.zip', '-linux-x64.tar.gz', '-linux-amd64.deb',
                '-linux-x86_64.rpm', '-linux-x86_64.AppImage']
    target = Path('release-assets')
    target.mkdir(exist_ok=False)
    for suffix in suffixes:
        name = stem + suffix
        matches = list(source.rglob(name))
        if len(matches) != 1 or matches[0].stat().st_size < 1000:
            raise ValueError(f'Missing or ambiguous platform package: {name}')
        shutil.copy2(matches[0], target / name)
    shutil.copy2(manifest_path, target / 'versions.json')
    checksums = ''.join(f'{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n'
                        for file in sorted(target.iterdir()))
    (target / 'SHA256SUMS').write_text(checksums, encoding='utf-8')


if __name__ == '__main__':
    main()
