"""Build clean standard and portable Windows ZIPs from one compiled bundle."""
from pathlib import Path
import zipfile


def create_archives(bundle, output, tag):
    bundle, output = Path(bundle), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in bundle.rglob('*') if p.is_file()
                   and p.relative_to(bundle).parts[0].lower() not in ('user_data', 'portable.flag')
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
                stream.writestr('��Я��ʹ��˵��.txt',
                    '������ѹ������ easy_tv_live.exe��\n'
                    '���á�Դ�б���Ƶ�����汣���� user_data/shared_preferences.json��\n'
                    '�������� user_data��Ǩ�����˳��������������ļ��С�\n'
                    '�����ļ�Դ��ԭ�ļ���·��������Ǩ�ƣ�����ͬʱ����ͬһĿ¼�Ķ��ʵ����\n'
                    '��ŵ���д��Ȩ�޵�Ŀ¼������ portable.flag����Ҫֱ����ѹ���������С�\n')
        archives.append(archive)
    return archives
