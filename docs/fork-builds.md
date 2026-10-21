# 本仓库的源管理与打包

本项目主要供个人自用，通过 Codex 辅助维护。当前修改仅在 Windows 11 上进行构建与运行验证；其他操作系统和设备尚未验证，不保证兼容性或可用性。

- 打开“订阅资源”，在需要更新的源卡片上点击“更新源”。网络源重新获取，本地源重新读取文件；更新未使用的源不会切换播放。
- 每个订阅独立保存缓存和更新时间。时间表示本机最近成功获取并解析该源的时间，不是源站修改时间。失败保留缓存和时间，没有成功记录时显示“尚未更新”。
- 不再自动添加默认源；升级时移除旧内置源记录，保留用户源。所有源均可删除；删除当前源会清空播放列表，最后一个源删除后保持空列表。本地文件不会被删除。
- 隐藏赞赏入口；桌面/电视设置默认打开订阅资源。订阅源扫码推送功能保留。
- 设置页和电视设置底部显示 `2.9.9 · YYYY-MM-DD`。正式工作流使用 UTC+8 日期；没有注入日期时只显示版本号。
- 添加和编辑网络源时可分别填写地址、标题及 User-Agent；已有 `tl`、`ua` 参数自动回填，留空会移除对应参数，其他 URL 参数保持原编码。User-Agent 仅用于视频播放请求。
- 本次源管理改动已通过 17 项 Flutter 测试，通过多平台 Release 发布；仅 Windows 11 做过运行验证。Windows 验证范围见 README。

## Windows 本地预览与构建

使用 Flutter 3.41.5，安装 Visual Studio Build Tools 2022 的 C++ 桌面开发组件，并开启 Windows 开发者模式。以下 PowerShell 命令假设 Flutter、Python 已加入 PATH，并在项目根目录执行：

```powershell
flutter pub get
python scripts/prepare_windows_fvp.py
flutter test --no-pub
$date = (Get-Date).ToString('yyyy-MM-dd')
# 本地预览沿用已发布构建号；正式发布由工作流生成递增编号。
$defines = @("--dart-define=BUILD_DATE=$date", '--dart-define=BUILD_NUMBER=11000301', '--dart-define=isTV=false')
flutter run -d windows --no-pub @defines
# 退出预览后打包：
flutter build windows --release --no-pub --build-name=2.9.9 --build-number=11000301 @defines
Copy-Item windows/system32/* build/windows/x64/runner/Release/ -Force
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath "easyTV-2.9.9-$date-windows-local.zip" -Force
```

请使用短路径存放本地构建源码，例如 `C:\dev\easy_tv_live`，避免 MSVC 插件头文件超过路径长度限制。FVP 首次构建需要下载 MDK SDK；本机验证使用适配 VS2022 的 MDK v0.35.0。完整分发 Release 目录或其 ZIP，不能仅分发 EXE。

本机另备有不纳入 Git 的 `preview-windows.cmd`、`test-local.cmd` 和 `build-windows.cmd`。打包脚本会将当前源码复制至较短临时路径后编译；这些入口及本机缓存不属于仓库提供的通用构建依赖。

## 发布

在 GitHub Actions 手动运行 Multi-Platform Build，或推送一个**新的** tag，会创建草稿 Release。需要直接发布时，在 PR 中更新 `release-request.json`，审查后合并到 main；仅这个文件在 main 发生更改时才触发正式发布，普通代码和频道源更新不触发。正式发布仍须通过测试、全部平台构建和附件完整性检查。重复发布请使用新 tag，避免覆盖旧包。Android 发布需要在仓库配置原有的四个签名 secrets；覆盖旧安装需要使用相同签名。

一次工作流的各平台共用同一份 `build_metadata.json`，注入打包日期、内部构建号，公开版本号仍为 2.9.9。构建号为 `12000000 + GITHUB_RUN_NUMBER × 100 + GITHUB_RUN_ATTEMPT`，后续运行递增，同一次运行重试也有独立编号。生成时会检查 Android ABI 编码范围；不要发布比最新已发布运行更早的运行重试产物。

生成的 `versions.json` 随安装包附在草稿 Release 中。确认附件齐全后发布为最新正式 Release，客户端从 `releases/latest/download/versions.json` 检查版本和构建号；同版本的新构建也可提示更新。下载使用 manifest 的 `release_tag`，与包文件名保持一致。未发布的草稿不会触发客户端更新。根目录旧的 `versions.json` 不再作为在线更新依据。

本地打包示例：

```sh
# 本地重复发布时递增 GITHUB_RUN_NUMBER（CI 会自动提供）。
GITHUB_RUN_NUMBER=1 python scripts/build_metadata.py
# 将 build_metadata.json 内的 BUILD_NUMBER 代入下面的内部构建号。
flutter build apk --dart-define-from-file=build_metadata.json --build-name=2.9.9 --build-number=<内部构建号> --dart-define=isTV=false --release
```

本地元数据脚本会更新 versions.json；这些生成文件无需提交。源码中的 pubspec 版本保持不变。

验证：`python -m unittest discover -s scripts -p 'test_*.py'`；`flutter test test/source_refresh_test.dart test/build_info_test.dart`。
