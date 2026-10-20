"""Create a complete Windows bundle and verify its required runtime files."""
import hashlib
import json
from pathlib import Path
import shutil
import zipfile


def main():
    metadata = json.loads(Path('versions.json').read_text(encoding='utf-8'))
    bundle = Path('build/windows/x64/runner/Release')
    for name in ('easy_tv_live.exe', 'flutter_windows.dll', 'mdk.dll', 'data/icudtl.dat', 'data/app.so'):
        if not (bundle / name).is_file():
            raise ValueError(f'Missing runtime file: {name}')
    packages = Path('packages')
    packages.mkdir(exist_ok=True)
    base = packages / f"easyTV-{metadata['release_tag']}-windows"
    archive = Path(shutil.make_archive(str(base), 'zip', bundle))
    with zipfile.ZipFile(archive) as stream:
        if stream.testzip() is not None:
            raise ValueError('Invalid ZIP')
    shutil.copy2('versions.json', packages / 'versions.json')
    sums = ''.join(f'{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n'
                   for file in (archive, packages / 'versions.json'))
    (packages / 'SHA256SUMS').write_text(sums, encoding='utf-8')


if __name__ == '__main__':
    main()
