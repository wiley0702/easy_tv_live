"""Generate shared build defines and the manifest shipped with a published release."""
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
import re
from urllib.request import Request, urlopen


def generate(now, ref_type='', ref_name='', run_number=1, run_attempt=1, minimum_build=0):
    local = now.astimezone(timezone(timedelta(hours=8)))
    # Preserve room for Flutter's per-ABI offsets. Attempts of a run
    # get unique codes; a subsequent workflow run has a higher code.
    if not 1 <= run_attempt < 100:
        raise ValueError('Run attempt must be between 1 and 99')
    number = max(12000000 + run_number * 100 + run_attempt, minimum_build + 1)
    if not 10260922 < number < 100000000:
        raise ValueError('Build number is outside the supported Android range')
    tag = ref_name if ref_type == 'tag' else f'2.9.9-{local:%Y%m%d}-{number}'
    return {
        'BUILD_DATE': local.strftime('%Y-%m-%d'),
        'BUILD_NUMBER': str(number),
    }, {
        'latest_version': '2.9.9',
        'latest_build': number,
        'build_date': local.strftime('%Y-%m-%d'),
        'release_tag': tag,
        'update_log': ['Windows 增加置顶按钮及 Ctrl+Shift+T', '新增 Windows 便携版，数据随软件目录迁移', 'README 汇总相对原版的累计功能差异', '仅 Windows 11 做过运行验证，其他平台未实机验证'],
    }


def published_build_floor():
    """Include non-Latest and draft releases; fail closed on API errors in CI."""
    if os.getenv('GITHUB_ACTIONS') != 'true':
        return 0
    repository = os.environ['GITHUB_REPOSITORY']
    token = os.environ['GH_TOKEN']
    floor = 0
    page = 1
    while True:
        request = Request(f'https://api.github.com/repos/{repository}/releases?per_page=100&page={page}',
                          headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json'})
        with urlopen(request, timeout=30) as response:
            releases = json.load(response)
        for release in releases:
            match = re.fullmatch(r'2\.9\.9-\d{8}-(\d+)', release['tag_name'])
            if match:
                floor = max(floor, int(match.group(1)))
        if len(releases) < 100:
            return floor
        page += 1


def main():
    defines, manifest = generate(datetime.now(timezone.utc),
        os.getenv('GITHUB_REF_TYPE', ''), os.getenv('GITHUB_REF_NAME', ''),
        int(os.getenv('GITHUB_RUN_NUMBER', '1')), int(os.getenv('GITHUB_RUN_ATTEMPT', '1')), published_build_floor())
    Path('build_metadata.json').write_text(json.dumps(defines, indent=2), encoding='utf-8')
    Path('versions.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if output := os.getenv('GITHUB_OUTPUT'):
        with open(output, 'a', encoding='utf-8') as stream:
            stream.write(f"build_number={defines['BUILD_NUMBER']}\n")
            stream.write(f"release_tag={manifest['release_tag']}\n")


if __name__ == '__main__':
    main()
