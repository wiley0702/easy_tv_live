![logo](https://fastly.jsdelivr.net/gh/aiyakuaile/images/tv-flow.png)

[![English](https://img.shields.io/badge/Language-English-blueviolet?style=for-the-badge)](README-en.md)
[![简体中文](https://img.shields.io/badge/语言-简体中文-blueviolet?style=for-the-badge)](README.md)

# 极简TV

极简TV,一款轻量级，支持全平台及安卓电视大屏的IPTV播放器，简洁易用，欢迎下载体验！

本仓库基于 [aiyakuaile/easy_tv_live](https://github.com/aiyakuaile/easy_tv_live) 进行维护，当前公开版本号保持 **2.9.9**，通过打包日期区分构建，例如 `2.9.9 · 2026-10-20`。

> 本项目主要供个人自用，通过 **Codex 辅助维护**。仅 **Windows 11 做过运行验证**；其他平台提供自动化构建包，但未进行设备或系统运行验证，不保证兼容性或可用性。

## 本次变更

- **切换分组不换台**：Windows 常用频道列表切组时仅浏览，点击具体频道才播放；重新打开列表定位到正在播放的频道。电视专用遥控器列表仍沿用原交互。
- **不再内置默认源**：首次打开为空列表，需要自行添加；升级时清理旧的内置默认源记录，保留用户添加的源。
- **每个源都可删除**：包括正在使用的源。删除前会确认；删除当前源会清空其播放列表，删除最后一个源后不会自动恢复默认源。本地源的删除仅移除订阅记录，不删除原文件。
- **每个源独立更新**：源卡片提供“更新源”按钮，网络源重新获取内容，本地源重新读取文件；更新未使用的源不会切换当前播放。
- **显示更新时间**：原“创建时间”改为“更新时间”，表示本机最近成功获取并解析该源的时间。没有成功记录时显示“尚未更新”；失败保留原缓存和时间。这不是源站文件的修改时间。
- **精简设置页**：隐藏“扫码赞赏”和“赞赏榜”入口，桌面/电视设置默认打开“订阅资源”。添加订阅源使用的扫码推送功能仍保留。
- **直接填写标题和 User-Agent**：添加或编辑网络源时，可分别填写订阅地址、显示标题和 User-Agent；已有 URL 中的 `tl`、`ua` 参数会自动填入，也可以修改或清空。

> 本次提供 Windows、Android、iOS、macOS 和 Linux 构建包。**仅 Windows 11 做过运行验证，其他平台未实机验证。** 下载前请阅读对应 Release 的说明。

## 下载与开始使用

正式发布包见 [本仓库 Releases](https://github.com/wiley0702/easy_tv_live/releases)。

1. Windows 用户下载对应 ZIP，**完整解压后**运行 `easy_tv_live.exe`，请保留同目录的 DLL 和 `data` 文件夹。
2. 打开“订阅资源”，选择“网络添加”输入订阅地址，或选择“本地添加”导入 M3U/TXT 文件。
3. 在源卡片点击“更新源”，确认获取成功及更新时间；需要切换时使用“设为默认”按钮（界面名称随语言变化）。

本应用不提供节目内容；第三方订阅源的可用性取决于源站及网络环境。

#### 功能

- [x] 全平台支持的IPTV播放器
- [x] 增加对.m3u文件的解析支持
- [x] 增加对.txt文件的解析支持
- [x] 支持切换字体和字体大小
- [x] 支持使用Bing每日图片作为视频背景
- [x] 相同频道自动合并，自动分组
- [x] 支持数字换台
- [x] 支持[Basic认证](#basic认证)请求订阅源(v2.9.1新增)
- [x] 支持添加本地文件为订阅源(v2.9.5新增)
- [x] 远程配置数据源(v2.9.6新增)
- [x] 支持自定义[User-Agent](#user-agent)(v2.9.7新增)

### TV版交互

⬆️上键：切换频道

⬇️下键：切换频道

⬅️左键：进入设置

➡️右键：进入线路切换

🆗ok键：确认操作、显示频道列表

### 非TV版交互
![image_4](https://raw.githubusercontent.com/aiyakuaile/easy_tv_live/main/img_4.png)

### 远程配置功能
>支持远程配置的字段，您可以前往[极简TV远程配置项](https://aiyakuaile.github.io/tv-setting)页面进行设置。
设置完成后，您可以点击页面下方的`下载数据`或者`复制Json`按钮。
> 
> 拿到Json数据后，您可以在Github或Gitee(码云)新建一个仓库，将Json数据上传到仓库后，获取到上传过文件的Raw链接。
>
> 在添加远程配置链接之前，请先在浏览器尝试，确定链接是可以正常请求和返回Json数据的。
>
> 之后在应用的设置页面，`远程配置`一栏中添加此链接。
>
> TV端可以通过扫码推送添加后，程序会自动应用配置。其他端粘贴链接后，点击`应用远程配置`按钮，即可完成。
> >直接修改Json数据是不会生效的，当需要覆盖应用的设置时，Json字段中的`dtaId`必须改变。如果你使用的是[极简TV远程配置项](https://aiyakuaile.github.io/tv-setting)
来生成的Json数据的，则无需担心，程序会自动修改`dtaId`


### User-Agent
添加网络源时可直接填写“User-Agent”；已有源点击“编辑”即可修改。此字段用于视频播放请求，不用于下载订阅文件。留空时使用源文件中的提示或底层播放器默认值。原有 URL 参数方式仍兼容：

订阅源支持自定义User-Agent，程序会默认解析m3u文件中，如下格式的User-Agent设置
```
#UA-Hint: 请将 User-Agent 设置为 okHttp/Mod-1.0.0 ，否则无法观看
```
> 如果无法正常解析出User-Agent，请按照如何格式配置订阅源：
> ```
> https://xxxxxxxxxxxxx.m3u?ua=okHttp/Mod-1.0.0
> ```
> 如果订阅源已经有其他参数了，请按照如下格式添加：
> ```
> https://xxxxxxxxxxxxx.m3u?other=123&ua=okHttp/Mod-1.0.0
> ```
> 最后把修改后的订阅源添加到App中。应用解析到User-Agent后，会有一个toast提示，如：`User-Agent=okHttp/Mod-1.0.0`

### 自定义订阅源的显示标题
添加或编辑网络源时可直接填写“显示标题”，留空时使用地址中的文件名。也支持下述 URL 参数方式：

订阅源支持自定义显示标题，需要按照以下方式进行配置
 ```
 https://xxxxxxxxxxxxx.m3u?tl=自定义标题
  > 或者
 https://xxxxxxxxxxxxx.m3u?other=123&tl=自定义标题
 ```

### Basic认证
订阅源支持Basic认证请求，请求格式如下
```
https://username:password@xxxxxxxxx.m3u
例如：https://aiyakuaile:a123456@baidu.com/easy_tv_live/live.m3u
```
### 字体
支持切换的字体需要使用[easy_tv_font](https://github.com/aiyakuaile/easy_tv_font)这个项目,
您如果想要添加其他字体，请按照这个项目的提示进行操作。

> iOS 的 IPA 需要自行签名安装；其他平台请根据实际构建包及目标设备验证兼容性。

> 如果添加的直播源是ipv6地址，请先确认您当前的网络是否可以正常访问ipv6地址
> [ipv6测试地址](https://v6t.ipip.net/)

## Windows 本地开发与打包

本次验证使用 Flutter **3.41.5**、Visual Studio Build Tools 2022，以及“使用 C++ 的桌面开发”组件（含 MSVC、CMake、Windows SDK）；Windows 需开启开发者模式，以便 Flutter 创建插件符号链接。

运行、测试、打包命令及路径长度问题的处理见 [源管理与构建说明](docs/fork-builds.md)。建议先在本地预览并验证，再提交或发布。Android 独立签名与 Windows 本地构建相互独立。

## 界面参考（上游旧版截图）

以下图片用于展示基础播放器界面，源管理和设置项请以当前构建为准。


![image_2](https://raw.githubusercontent.com/aiyakuaile/easy_tv_live/main/img_2.jpeg)

![image_1](https://raw.githubusercontent.com/aiyakuaile/easy_tv_live/main/img_1.jpeg) | ![image_3](https://raw.githubusercontent.com/aiyakuaile/easy_tv_live/main/img_3.jpeg)
---|---


## 致谢与贡献

感谢上游 [aiyakuaile/easy_tv_live](https://github.com/aiyakuaile/easy_tv_live) 及其贡献者提供基础项目，字体资源来自 [easy_tv_font](https://github.com/aiyakuaile/easy_tv_font)。许可证见 [LICENSE](LICENSE)。

问题与建议请提交至 [本仓库 Issues](https://github.com/wiley0702/easy_tv_live/issues)，欢迎提交 Pull Request。
