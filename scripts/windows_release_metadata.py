"""Prepare metadata and the pinned VS2022 media dependency for Windows releases."""
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path


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
    from prepare_windows_mdk import prepare
    prepare()


if __name__ == '__main__':
    main()
