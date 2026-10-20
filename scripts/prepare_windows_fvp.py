"""Resolve the FVP extraction directory for recent CMake archive safety checks."""
import json
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname


def main():
    config = Path('.dart_tool/package_config.json').resolve()
    packages = json.loads(config.read_text(encoding='utf-8'))['packages']
    package = next(item for item in packages if item['name'] == 'fvp')
    uri = urlparse(urljoin(config.as_uri(), package['rootUri']))
    if uri.scheme != 'file':
        raise ValueError('Expected a local FVP package')
    dependency = Path(url2pathname(uri.path)).resolve() / 'cmake' / 'deps.cmake'
    content = dependency.read_text(encoding='utf-8')
    if 'FVP_REAL_SOURCE_DIR' not in content:
        source = '      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}'
        if content.count(source) != 1 or content.count('    execute_process(') != 1:
            raise ValueError('FVP extraction code changed; review the workaround')
        content = content.replace('    execute_process(',
            '    get_filename_component(FVP_REAL_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)\n'
            '    execute_process(', 1)
        content = content.replace(source, '      WORKING_DIRECTORY "${FVP_REAL_SOURCE_DIR}"')
        dependency.write_text(content, encoding='utf-8', newline='\n')
    print('FVP archive extraction uses the real package directory.')


if __name__ == '__main__':
    main()
