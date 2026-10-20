"""Generate shared build defines and the manifest shipped with a published release."""
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path


def generate(now, ref_type='', ref_name='', run_number=1, run_attempt=1):
    local = now.astimezone(timezone(timedelta(hours=8)))
    # Preserve room for Flutter's per-ABI offsets. Attempts of a run
    # get unique codes; a subsequent workflow run has a higher code.
    if not 1 <= run_attempt < 100:
        raise ValueError('Run attempt must be between 1 and 99')
    number = 11000000 + run_number * 100 + run_attempt
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
        'update_log': ['增加订阅源刷新按钮和最近成功刷新时间', '显示打包日期，支持同版本构建更新'],
    }


def main():
    defines, manifest = generate(datetime.now(timezone.utc),
        os.getenv('GITHUB_REF_TYPE', ''), os.getenv('GITHUB_REF_NAME', ''),
        int(os.getenv('GITHUB_RUN_NUMBER', '1')), int(os.getenv('GITHUB_RUN_ATTEMPT', '1')))
    Path('build_metadata.json').write_text(json.dumps(defines, indent=2), encoding='utf-8')
    Path('versions.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if output := os.getenv('GITHUB_OUTPUT'):
        with open(output, 'a', encoding='utf-8') as stream:
            stream.write(f"build_number={defines['BUILD_NUMBER']}\n")
            stream.write(f"release_tag={manifest['release_tag']}\n")


if __name__ == '__main__':
    main()
