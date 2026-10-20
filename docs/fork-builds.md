# 本仓库的源刷新与打包

- 手机、桌面和电视端：打开“订阅资源”，点击“更新源”。按钮更新当前选中的订阅；本地订阅重新读取文件。时间表示本机最近成功获取并解析该订阅的时间，不是源站文件修改时间。
- 每个订阅独立保存缓存和时间；更新失败保留旧频道，使用缓存不修改成功时间。首次升级没有历史刷新时间时显示“尚未刷新”。
- 默认频道源来自 `wiley0702/easy_tv_live/main/temp`。现有自定义订阅不受影响。
- 设置页和电视设置底部显示 `2.9.9 · YYYY-MM-DD`；打包日期按 UTC+8 生成。开发时没有注入日期则仅显示版本号。

## 发布

在 GitHub Actions 手动运行 Multi-Platform Build，或推送一个**新的** tag。工作流只创建草稿 Release，不自动发布。重复发布请使用新 tag，避免覆盖旧包。Android 发布需要在仓库配置原有的四个签名 secrets；覆盖旧安装需要使用相同签名。

一次工作流的各平台共用同一份 `build_metadata.json`，注入打包日期、内部构建号，公开版本号仍为 2.9.9。构建号为 `11000000 + GITHUB_RUN_NUMBER × 100 + GITHUB_RUN_ATTEMPT`，后续运行递增，同一次运行重试也有独立编号。生成时会检查 Android ABI 编码范围；不要发布比最新已发布运行更早的运行重试产物。

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
