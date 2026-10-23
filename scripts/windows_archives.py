"""Build clean standard and portable Windows ZIPs from one compiled bundle."""
from pathlib import Path
import zipfile


def create_archives(bundle, output, tag):
    bundle, output = Path(bundle), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in bundle.rglob('*') if p.is_file()
                   and p.relative_to(bundle).parts[0].lower() not in ('user_data', 'portable.flag', '便携版使用说明.txt')
                   and p.suffix.lower() != '.zip')
    for required in ('easy_tv_live.exe', 'flutter_windows.dll', 'data/app.so'):
        if bundle / required not in files:
            raise ValueError(f'Missing runtime file: {required}')
    archives = []
    for portable in (False, True):
        suffix = 'windows-portable' if portable else 'windows'
        archive = output / f'easyTV-{tag}-{suffix}.zip'
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as stream:
            for file in files:
                stream.write(file, file.relative_to(bundle).as_posix())
            if portable:
                stream.writestr('portable.flag', 'Portable mode enabled\n')
                stream.writestr('user_data/', '')
                stream.writestr('便携版使用说明.txt',
                    '完整解压后运行 easy_tv_live.exe。\n'
                    '设置、源列表、频道缓存保存在 user_data/shared_preferences.json。\n'
                    '升级保留 user_data；迁移请退出软件后复制整个文件夹。\n'
                    '本地文件源的原文件和路径需另行迁移；请勿同时运行同一目录的多个实例。\n'
                    '请放到有写入权限的目录，保留 portable.flag，不要直接在压缩包内运行。\n')
        archives.append(archive)
    return archives
