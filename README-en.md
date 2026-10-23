![logo](https://fastly.jsdelivr.net/gh/aiyakuaile/images/tv-flow.png)

[![English](https://img.shields.io/badge/Language-English-blueviolet?style=for-the-badge)](README-en.md)
[![简体中文](https://img.shields.io/badge/语言-简体中文-blueviolet?style=for-the-badge)](README.md)

# EasyTV
EasyTV is a lightweight IPTV player that supports all platforms and Android TV large screens. It is simple and easy to use. Welcome to download and experience!

This fork is based on [aiyakuaile/easy_tv_live](https://github.com/aiyakuaile/easy_tv_live). The public version remains **2.9.9**, with a build date appended, for example `2.9.9 · 2026-10-20`.

> This project is primarily for personal use and is maintained with **Codex assistance**. **Only Windows 11 has been runtime-tested.** Other platforms have automated build packages but have not been runtime-tested on their target systems or devices; compatibility and availability are not guaranteed.

## Functional differences from upstream

This list describes the cumulative functional differences introduced by this fork. Per-release history is available in [Releases](https://github.com/wiley0702/easy_tv_live/releases).

- No bundled default source; users start with an empty subscription list.
- Every source can be deleted, including the active or last source. Local files are retained.
- Refresh sources individually and display the last successful local update time; inactive updates do not switch playback, and failures retain caches.
- Separate title and User-Agent fields when adding or editing sources, compatible with `tl` and `ua` URL parameters. User-Agent applies to video playback requests.
- Browsing groups in the standard Windows channel list does not change playback until a channel is clicked. The dedicated TV remote list retains its original interaction.
- Restore the playing station by identity after refresh, retaining an unchanged stream and User-Agent; start from valid cached channels and refresh in the background.
- Temporary six-digit pairing codes protect LAN subscription/configuration push and sync. Sync preserves local file sources on the receiver; both peers need updated fork clients.
- Donation entries are hidden; desktop/TV settings open subscriptions first. QR source input remains available.
- Windows always-on-top button in playback controls and the empty-channel page. Ctrl+Shift+T toggles while the app has focus; the setting resets on restart.
- Separate Windows portable ZIP stores settings, subscriptions and channel caches in the adjacent `user_data` folder for migration.
- Public version remains 2.9.9 with a build date displayed in the app; Android packages use this fork's independent signing certificate.

## Download and get started

Published packages are available in [this fork's Releases](https://github.com/wiley0702/easy_tv_live/releases).

1. Windows standard builds use AppData; portable builds use the adjacent `user_data` folder. Preserve it during upgrades and close the app before copying the full folder for migration. Local source files and their paths require separate migration. Extract the entire ZIP and run `easy_tv_live.exe`. Keep the DLLs and `data` directory beside it.
2. Open subscriptions and add a network URL or a local M3U/TXT file.
3. Refresh the source and check its update time. Use the source selection button to change the active source.

The app does not provide channels. Third-party source availability depends on the provider and your network.

#### Features
- [x] IPTV player that supports all platforms
- [x] Support for parsing .m3u files
- [x] Support for parsing .txt files (added in v1.5.0)
- [x] Support switching fonts and font sizes
- [x] Support using Bing daily images as video backgrounds
- [x] Automatically merge and group the same channels
- [x] Support channel switching via number keys
- [x] Support [Basic Authentication](#basic-authentication) for requesting subscription sources (new in v2.9.1)
- [x] Support adding local files as subscription sources (new in v2.9.5)
- [x] Remote Configuration Feature
- [x] Support custom [User-Agent](#user-agent)（new in v2.9.7）

#### TV Version Interaction

⬆️ Up Arrow: Switch Channel

⬇️ Down Arrow: Switch Channel

⬅️ Left Arrow: Enter Settings

➡️ Right Arrow: Switch Source Line

🆗 OK Button: Confirm operation, display channel list

### NOT TV Version Interaction
![image_4](https://raw.githubusercontent.com/aiyakuaile/easy_tv_live/main/img_4.png)

#### Remote Configuration Feature
Fields that support remote configuration can be set on the [极简TV远程配置项](https://aiyakuaile.github.io/tv-setting) page.
After setting, you can click the `下载数据` or `复制Json` button at the bottom of the page.

After obtaining the Json data, you can create a new repository on Github or Gitee, upload the Json data to the repository, and then obtain the Raw link of the uploaded file.

Before adding the remote configuration link, please try it in the browser first to ensure that the link can normally request and return Json data.

Then, add this link in the `远程配置` section of the app's settings page.

For TV versions, you can add it via scanning the push notification, and the program will 
automatically apply the configuration. For other versions, paste the link and click the `应用远程配置` 
button to complete.
>Modifying the JSON data directly will not take effect. When you need to override the app's settings, the `dtaId` field in the JSON must be changed. If you are using the [极简TV远程配置项](https://aiyakuaile.github.io/tv-setting) to generate the JSON data, you don't need to worry, as the program will automatically modify the `dtaId`.


### User-Agent
Enter a User-Agent in the network source dialog, or use Edit to change it later. It applies to video playback, not subscription downloads. Leaving it blank uses the source file hint or player default. URL parameters remain supported.

The subscription source supports custom User-Agent. The program will parse the User-Agent settings in the following format by default in m3u files:
```
#UA-Hint: 请将 User-Agent 设置为 okHttp/Mod-1.0.0 ，否则无法观看
```
> If the User-Agent cannot be parsed correctly, please configure the subscription source according to the following format:
> ```
> https://xxxxxxxxxxxxx.m3u?ua=okHttp/Mod-1.0.0
> ```
> If the subscription source already has other parameters, please add it in the following format:
> ```
> https://xxxxxxxxxxxxx.m3u?other=123&ua=okHttp/Mod-1.0.0
> ```
> Finally, add the modified subscription source to the App. After the application parses the User-Agent, there will be a toast prompt, such as: `User-Agent=okHttp/Mod-1.0.0`

### Custom Display Title for Subscription Sources
Use the display title field when adding or editing a network source. Leave it blank to use the filename from the URL. URL parameters remain supported as described below.

The subscription source supports custom display titles. You need to configure it as follows:
 ```
 https://xxxxxxxxxxxxx.m3u?tl=your-title
 or
 https://xxxxxxxxxxxxx.m3u?other=123&tl=your-title
 ```

### Basic-Authentication
The subscription source supports Basic Authentication requests. The request format is as follows:
```
https://username:password@xxxxxxxxx.m3u
For example: https://aiyakuaile:a123456@baidu.com/easy_tv_live/live.m3u
```

#### Fonts
The fonts that support switching need to use the [easy_tv_font](https://github.com/aiyakuaile/easy_tv_font) project. If you want to add other fonts, please follow the instructions in this project.

> For iOS, after downloading the ipa, you need to sign it for installation using tools.
> If the added live source is an IPv6 address, please confirm that your current network can access IPv6 addresses normally.
> [IPv6 Test Address](https://v6t.ipip.net/)

## Local Windows development

The local build was verified with Flutter **3.41.5**, Visual Studio Build Tools 2022 and the C++ desktop workload, including MSVC, CMake and a Windows SDK. Enable Windows Developer Mode for Flutter plugin symlinks.

See the [source management and build guide (Chinese)](docs/fork-builds.md) for commands and Windows path-length handling. Preview and test locally before committing or publishing.

## Interface reference (older upstream screenshots)

These screenshots show the base player interface. Source management and settings may differ in the current build.


![image_2](https://raw.githubusercontent.com/aiyakuaile/easy_tv_live/main/img_2.jpeg)

![image_1](https://raw.githubusercontent.com/aiyakuaile/easy_tv_live/main/img_1.jpeg) | ![image_3](https://raw.githubusercontent.com/aiyakuaile/easy_tv_live/main/img_3.jpeg)
---|---


## Credits and contributions

Thanks to [aiyakuaile/easy_tv_live](https://github.com/aiyakuaile/easy_tv_live) and its contributors for the original project, and [easy_tv_font](https://github.com/aiyakuaile/easy_tv_font) for font resources. See [LICENSE](LICENSE).

Report issues in [this fork's issue tracker](https://github.com/wiley0702/easy_tv_live/issues). Pull requests are welcome.
