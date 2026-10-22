import 'dart:async';
import 'dart:io';

import 'package:easy_tv_live/provider/download_provider.dart';
import 'package:easy_tv_live/provider/theme_provider.dart';
import 'package:easy_tv_live/util/latency_checker_util.dart';
import 'package:easy_tv_live/util/remote_util.dart';
import 'package:easy_tv_live/widget/focus_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading_plus/flutter_easyloading_plus.dart';
import 'package:provider/provider.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'channel_drawer_page.dart';
import 'entity/play_channel_list_model.dart';
import 'generated/l10n.dart';
import 'mobile_video_widget.dart';
import 'table_video_widget.dart';
import 'tv/tv_page.dart';
import 'util/check_version_util.dart';
import 'util/env_util.dart';
import 'util/epg_util.dart';
import 'util/log_util.dart';
import 'util/m3u_util.dart';
import 'util/playlist_selection.dart';
import 'widget/empty_page.dart';

class LiveHomePage extends StatefulWidget {
  const LiveHomePage({super.key, this.initialPlaylist, this.controllerFactory});
  final PlayChannelListModel? initialPlaylist;
  final VideoPlayerController Function(Uri, Map<String, String>)? controllerFactory;

  @override
  State<LiveHomePage> createState() => _LiveHomePageState();
}

class _LiveHomePageState extends State<LiveHomePage> {
  String toastString = S.current.loading;

  PlayChannelListModel? _channelListModel;

  Channel? _currentChannel;

  int _sourceIndex = 0;

  VideoPlayerController? _playerController;

  bool isBuffering = false;

  bool isPlaying = false;
  double aspectRatio = 16 / 9;

  bool _drawerIsOpen = false;

  int _channelSerialNum = 1;

  int _playGeneration = 0;
  Timer? _retryTimer;

  bool _isCurrentPlayback(int generation) => mounted && generation == _playGeneration;

  Future<void> _disposeController(VideoPlayerController? controller) async {
    if (controller == null) return;
    controller.removeListener(_videoListener);
    try {
      await controller.dispose().timeout(const Duration(seconds: 3));
    } catch (error) {
      LogUtil.e('Player disposal failed: $error');
    }
  }

  Future<void> _playVideo(String entMsg) async {
    final generation = ++_playGeneration;
    _retryTimer?.cancel();
    _retryTimer = null;
    final channel = _currentChannel;
    final urls = channel?.urls;
    if (!mounted) return;
    if (channel == null || urls == null || urls.isEmpty) {
      final old = _playerController;
      _playerController = null;
      await _disposeController(old);
      return;
    }
    _sourceIndex = _sourceIndex.clamp(0, urls.length - 1);
    final line = _sourceIndex;
    final url = urls[line];
    final ua = _channelListModel?.uaHint ?? '';
    _channelSerialNum = channel.serialNum ?? 1;
    context.read<ThemeProvider>().setPrePlaySerialNum(_channelSerialNum);
    final timeout = context.read<ThemeProvider>().timeoutSwitchLine;
    final old = _playerController;
    _playerController = null;
    setState(() {
      toastString = S.current.lineToast(line + 1, channel.title ?? '');
      isPlaying = false;
    });
    await _disposeController(old);
    if (!_isCurrentPlayback(generation)) return;
    final headers = ua.isEmpty ? <String, String>{} : {'User-Agent': ua};
    VideoPlayerController? controller;
    try {
      controller =
          widget.controllerFactory?.call(Uri.parse(url), headers) ??
          VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: false, mixWithOthers: false),
            httpHeaders: headers,
          );
      _playerController = controller;
      await controller.initialize().timeout(Duration(seconds: timeout));
      if (!_isCurrentPlayback(generation)) return;
      await controller.setVolume(1);
      if (!_isCurrentPlayback(generation)) return;
      controller.addListener(_videoListener);
      await controller.play();
      if (!_isCurrentPlayback(generation)) return;
      setState(() {
        toastString = S.current.loading;
        aspectRatio = controller!.value.aspectRatio;
      });
    } catch (error) {
      if (!_isCurrentPlayback(generation)) return;
      LogUtil.e('Playback initialization failed: $error');
      _playerController = null;
      await _disposeController(controller);
      if (_isCurrentPlayback(generation)) _scheduleNextLine(generation, channel, line);
    }
  }

  void _scheduleNextLine(int generation, Channel channel, int line) {
    if (!_isCurrentPlayback(generation) || _retryTimer != null) return;
    final next = line + 1;
    if (next >= (channel.urls?.length ?? 0)) {
      setState(() {
        isPlaying = false;
        isBuffering = false;
        toastString = S.current.playError(channel.title ?? '');
      });
      return;
    }
    setState(() => toastString = S.current.switchLine(next + 1));
    _retryTimer = Timer(const Duration(seconds: 2), () {
      _retryTimer = null;
      if (!_isCurrentPlayback(generation) || !identical(channel, _currentChannel)) return;
      _sourceIndex = next;
      _playVideo('fallback');
    });
  }

  void _videoListener() {
    final controller = _playerController;
    final channel = _currentChannel;
    if (!mounted || controller == null || channel == null) return;
    if (controller.value.hasError && !controller.value.isCompleted) {
      controller.removeListener(_videoListener);
      _scheduleNextLine(_playGeneration, channel, _sourceIndex);
      return;
    }
    if (isBuffering != controller.value.isBuffering || isPlaying != controller.value.isPlaying) {
      setState(() {
        isBuffering = controller.value.isBuffering;
        isPlaying = controller.value.isPlaying;
      });
    }
  }

  _onTapChannel(Channel? model) {
    _currentChannel = model;
    _sourceIndex = 0;
    if (_channelListModel != null && model != null) {
      _channelListModel!.playGroupIndex = model.groupIndex;
      _channelListModel!.playChannelIndex = model.channelIndex;
    }
    LogUtil.v('切换频道:::::${_currentChannel?.toJson()}');
    _playVideo('onTapChannel方法进入');
  }

  @override
  void initState() {
    super.initState();
    M3uUtil.refreshedPlaylist.addListener(_onSourceRefreshed);
    EasyLoading.instance
      ..loadingStyle = EasyLoadingStyle.custom
      ..indicatorColor = Colors.black
      ..textColor = Colors.black
      ..backgroundColor = Colors.white70;
    // if (!EnvUtil.isMobile) windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    Future.delayed(Duration.zero, _loadData);
  }

  _loadData() async {
    if (!mounted) return;
    if (widget.initialPlaylist != null) {
      _applyPlaylist(widget.initialPlaylist, true);
      return;
    }
    await RemoteUtil.getRemoteData(context);
    await _parseData(true);
    if (mounted) {
      if (context.read<ThemeProvider>().useAutoUpdate && Platform.isAndroid) {
        final url = await CheckVersionUtil.checkVersionAndAutoUpdate();
        if (mounted && url != null) {
          EasyLoading.showToast('新版本开始下载，稍后为您自动安装', toastPosition: EasyLoadingToastPosition.top);
          context.read<DownloadProvider>().downloadApk(url);
        }
      } else {
        if (context.read<ThemeProvider>().useLightVersionCheck) {
          CheckVersionUtil.checkLightVersion();
        } else {
          CheckVersionUtil.checkVersion(context, false, false);
        }
      }
    }
  }

  @override
  dispose() {
    _playGeneration++;
    _retryTimer?.cancel();
    M3uUtil.refreshedPlaylist.removeListener(_onSourceRefreshed);
    WakelockPlus.disable();
    unawaited(_disposeController(_playerController));
    _playerController = null;
    super.dispose();
  }

  _parseData([bool isSkipRestSerialNum = false]) async {
    final resMap = await M3uUtil.getDefaultM3uData();
    if (!mounted) return;
    // Preserve the currently working list when a refresh fails.
    if (resMap == null && _channelListModel != null) return;
    _applyPlaylist(resMap, isSkipRestSerialNum);
  }

  void _onSourceRefreshed() {
    if (mounted) _applyPlaylist(M3uUtil.refreshedPlaylist.value, true);
  }

  void _applyPlaylist(PlayChannelListModel? resMap, bool isSkipRestSerialNum) {
    final previous = _currentChannel;
    final previousUa = _channelListModel?.uaHint;
    _channelListModel = resMap;
    if (mounted && !isSkipRestSerialNum) {
      context.read<ThemeProvider>().setPrePlaySerialNum(1);
    }
    if ((_channelListModel?.playList?.isNotEmpty) ?? false) {
      if (mounted) {
        final preNum = context.read<ThemeProvider>().prePlaySerialNum;
        final matched = isSkipRestSerialNum ? PlaylistSelection.match(previous, _channelListModel!) : null;
        final channel = matched ?? (previous == null ? M3uUtil.serialNumMap[preNum.toString()] : null) ?? M3uUtil.serialNumMap['1'];
        final sameStream =
            matched != null &&
            previousUa == _channelListModel?.uaHint &&
            _sourceIndex < (matched.urls?.length ?? 0) &&
            _sourceIndex < (previous?.urls?.length ?? 0) &&
            matched.urls![_sourceIndex] == previous!.urls![_sourceIndex] &&
            _playerController?.value.isInitialized == true &&
            _playerController?.value.hasError == false &&
            _retryTimer == null;
        if (sameStream) {
          setState(() {
            _currentChannel = matched;
            _channelSerialNum = matched.serialNum ?? 1;
            _channelListModel!.playGroupIndex = matched.groupIndex;
            _channelListModel!.playChannelIndex = matched.channelIndex;
          });
          context.read<ThemeProvider>().setPrePlaySerialNum(_channelSerialNum);
        } else {
          _onTapChannel(channel);
          if (isSkipRestSerialNum && previous != null && matched == null) {
            EasyLoading.showToast('原频道已移除，已切换到第一个可用频道');
          }
        }
        if (_channelListModel!.type == PlayListType.m3u) {
          if (_channelListModel?.epgUrl != null && _channelListModel?.epgUrl != '') {
            EpgUtil.loadEPGXML(_channelListModel!.epgUrl!);
          }
        }
      }
    } else {
      _playGeneration++;
      _retryTimer?.cancel();
      _retryTimer = null;
      final old = _playerController;
      _playerController = null;
      unawaited(_disposeController(old));
      setState(() {
        _currentChannel = null;
        isPlaying = false;
        isBuffering = false;
        toastString = 'UNKNOWN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (EnvUtil.isTV()) {
      return TvPage(
        channelSerialNum: _channelSerialNum,
        channelListModel: _channelListModel,
        onTapChannel: _onTapChannel,
        toastString: toastString,
        controller: _playerController,
        isBuffering: isBuffering,
        isPlaying: isPlaying,
        aspectRatio: aspectRatio,
        onChangeSubSource: _parseData,
        changeChannelSources: _changeChannelSources,
      );
    }
    return Material(
      child: OrientationLayoutBuilder(
        portrait: (context) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          return MobileVideoWidget(
            toastString: toastString,
            controller: _playerController,
            changeChannelSources: _changeChannelSources,
            isLandscape: false,
            isBuffering: isBuffering,
            isPlaying: isPlaying,
            aspectRatio: aspectRatio,
            onChangeSubSource: _parseData,
            drawChild: ChannelDrawerPage(channelListModel: _channelListModel, onTapChannel: _onTapChannel, isLandscape: false),
            onPreviousChannel: _previousChannel,
            onNextChannel: _nextChannel,
            onSwitchSource: _switchSource,
          );
        },
        landscape: (context) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
              }
            },
            child: Scaffold(
              drawer: ChannelDrawerPage(channelListModel: _channelListModel, onTapChannel: _onTapChannel, isLandscape: true, isOpen: _drawerIsOpen),
              drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.3,
              drawerScrimColor: Colors.transparent,
              onDrawerChanged: (bool isOpened) {
                setState(() {
                  _drawerIsOpen = isOpened;
                });
              },
              body: Builder(
                builder: (context) {
                  return CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.arrowUp): _previousChannel,
                      const SingleActivator(LogicalKeyboardKey.arrowDown): _nextChannel,
                      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _pushChannelDrawer(context),
                      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _switchSource(),
                      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () => _changeChannelSources(),
                      if (Platform.isMacOS) const SingleActivator(LogicalKeyboardKey.comma, meta: true): () => _pushSettingPage(context),
                      if (Platform.isWindows || Platform.isLinux)
                        const SingleActivator(LogicalKeyboardKey.comma, control: true): () => _pushSettingPage(context),
                    },
                    child: Focus(
                      autofocus: true,
                      child: toastString == 'UNKNOWN'
                          ? InkWell(
                              canRequestFocus: false,
                              onTap: _parseData,
                              // onHover: (bool isHover) {
                              //   if (isHover) {
                              //     windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: true);
                              //   } else {
                              //     windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
                              //   }
                              // },
                              child: EmptyPage(
                                onRefresh: _parseData,
                                onEnterSetting: () async {
                                  await M3uUtil.openAddSource(context);
                                  _parseData();
                                },
                              ),
                            )
                          : TableVideoWidget(
                              toastString: toastString,
                              controller: _playerController,
                              isBuffering: isBuffering,
                              isPlaying: isPlaying,
                              aspectRatio: aspectRatio,
                              drawerIsOpen: _drawerIsOpen,
                              changeChannelSources: _changeChannelSources,
                              onChangeSubSource: _parseData,
                              isLandscape: true,
                              onPreviousChannel: _previousChannel,
                              onNextChannel: _nextChannel,
                              onSwitchSource: _switchSource,
                            ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _changeChannelSources([FocusNode? videoNode]) async {
    LogUtil.v('_changeChannelSources:::::::::::');
    videoNode?.unfocus();
    List<String> sources = _currentChannel!.urls!;
    final selectedIndex = await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.black87,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 40),
            color: Colors.transparent,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(sources.length, (index) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FocusButton(
                      autofocus: _sourceIndex == index,
                      onTap: _sourceIndex == index
                          ? null
                          : () {
                              Navigator.pop(context, index);
                            },
                      title: S.current.lineIndex(index + 1),
                      selected: _sourceIndex == index,
                    ),
                    Positioned(
                      top: -2,
                      right: 8,
                      child: FutureBuilder<Color>(
                        future: LatencyCheckerUtil.checkLatencies(sources[index]),
                        initialData: Colors.transparent,
                        builder: (BuildContext context, AsyncSnapshot<Color> snapshot) {
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: snapshot.data, borderRadius: BorderRadius.circular(4)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
    videoNode?.requestFocus();
    if (selectedIndex != null && _sourceIndex != selectedIndex) {
      _sourceIndex = selectedIndex;
      LogUtil.v('切换线路:====线路${_sourceIndex + 1}');
      _playVideo('changeChannelSources方法进入');
    }
  }

  _nextChannel() async {
    if (toastString == 'UNKNOWN') return;
    final lastIndex = _channelSerialNum + 1;
    final channel = M3uUtil.serialNumMap[lastIndex.toString()];
    if (channel != null) {
      _channelListModel!.playChannelIndex = channel.channelIndex;
      _channelListModel!.playGroupIndex = channel.groupIndex;
      _onTapChannel.call(channel);
    } else {
      EasyLoading.showToast('已是最后一个节目');
    }
  }

  _previousChannel() async {
    if (toastString == 'UNKNOWN') return;
    final lastIndex = _channelSerialNum - 1;
    final channel = M3uUtil.serialNumMap[lastIndex.toString()];
    if (channel != null) {
      _channelListModel!.playChannelIndex = channel.channelIndex;
      _channelListModel!.playGroupIndex = channel.groupIndex;
      _onTapChannel.call(channel);
    } else {
      EasyLoading.showToast('已是第一个节目');
    }
  }

  _switchSource() async {
    if (toastString == 'UNKNOWN') return;
    _sourceIndex = (_sourceIndex + 1) % _currentChannel!.urls!.length;
    if (_currentChannel!.urls!.length == 1) {
      EasyLoading.showToast('🤣没有更多线路！');
    }
    _playVideo('switchSource点击屏幕切换线路方法进入');
  }

  _pushSettingPage(BuildContext context) async {
    LogUtil.v('设置：：：：');
    _playerController?.pause();
    await M3uUtil.openAddSource(context);
    final isChange = await M3uUtil.isChangeChannelLink();
    if (isChange) {
      _parseData();
    } else {
      _playerController?.play();
    }
  }

  _pushChannelDrawer(BuildContext context) {
    if (toastString == 'UNKNOWN') return;
    LogUtil.v('节目菜单：：：：');
    Scaffold.of(context).openDrawer();
  }
}
