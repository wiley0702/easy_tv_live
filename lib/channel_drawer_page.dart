import 'dart:async';
import 'dart:math';

import 'package:easy_tv_live/entity/play_channel_list_model.dart';
import 'package:easy_tv_live/provider/theme_provider.dart';
import 'package:easy_tv_live/util/date_util.dart';
import 'package:easy_tv_live/util/epg_util.dart';
import 'package:easy_tv_live/util/log_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'util/env_util.dart';

class ChannelDrawerPage extends StatefulWidget {
  final PlayChannelListModel? channelListModel;
  final bool isLandscape;
  final bool isOpen;
  final Function(Channel? newChannel)? onTapChannel;

  const ChannelDrawerPage({super.key, required this.channelListModel, required this.onTapChannel, this.isLandscape = true, this.isOpen = true});

  @override
  State<ChannelDrawerPage> createState() => _ChannelDrawerPageState();
}

class _ChannelDrawerPageState extends State<ChannelDrawerPage> {
  final _scrollController = ScrollController();
  final _scrollChannelController = ScrollController();
  final _epgScrollController = ItemScrollController();
  List<EpgData>? _epgData;
  int _selEPGIndex = 0;

  final _viewPortKey = GlobalKey();
  double? _viewPortHeight;
  final _itemHeight = 50.0;
  bool _isShowEPG = true;
  final isTV = EnvUtil.isTV();
  int _browseGroupIndex = 0;
  Timer? _epgTimer;
  int _epgRequest = 0;

  bool _isPlayingChannel(int index) => widget.channelListModel?.playGroupIndex == _browseGroupIndex && widget.channelListModel?.playChannelIndex == index;

  @override
  void didUpdateWidget(covariant ChannelDrawerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.isOpen && widget.isOpen) || !identical(oldWidget.channelListModel, widget.channelListModel)) {
      _browseGroupIndex = widget.channelListModel?.playGroupIndex ?? 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final group = widget.channelListModel?.playGroupIndex ?? 0;
        final channel = widget.channelListModel?.playChannelIndex ?? 0;
        if (_scrollController.hasClients) _scrollController.jumpTo(min(group * _itemHeight, _scrollController.position.maxScrollExtent));
        if (_scrollChannelController.hasClients) _scrollChannelController.jumpTo(min(channel * _itemHeight, _scrollChannelController.position.maxScrollExtent));
        _loadEPGMsg();
      });
    }
  }

  void _loadEPGMsg() {
    _epgTimer?.cancel();
    final request = ++_epgRequest;
    if (!mounted) return;
    setState(() {
      _epgData = null;
      _selEPGIndex = 0;
    });
    final model = widget.channelListModel;
    if (!_isShowEPG || model?.playList?.isNotEmpty != true) return;
    final group = model!.playGroupIndex ?? 0;
    if (group < 0 || group >= model.playList!.length) return;
    final channels = model.playList![group].channel ?? <Channel>[];
    final index = model.playChannelIndex ?? 0;
    if (index < 0 || index >= channels.length) return;
    final channel = channels[index];
    _epgTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final res = await EpgUtil.getEpg(channel);
        if (!mounted || request != _epgRequest || res?.epgData?.isNotEmpty != true) return;
        final data = res!.epgData!;
        final now = DateUtil.formatDate(DateTime.now(), format: 'HH:mm');
        var selected = 0;
        for (var i = 0; i < data.length; i++) {
          if ((data[i].start ?? '').compareTo(now) <= 0) selected = i;
        }
        setState(() {
          _epgData = data;
          _selEPGIndex = selected;
        });
      } catch (error) {
        LogUtil.e('EPG load failed: $error');
      }
    });
  }

  @override
  void initState() {
    _browseGroupIndex = widget.channelListModel?.playGroupIndex ?? 0;
    LogUtil.v('ChannelDrawerPage:isTV:::$isTV');
    Future.delayed(Duration.zero, () {
      if (!mounted || widget.channelListModel?.playList?.isNotEmpty != true) return;
      if (_viewPortHeight == null) {
        final RenderBox? renderBox = _viewPortKey.currentContext?.findRenderObject() as RenderBox?;
        final double height = renderBox?.size.height ?? 0;
        _viewPortHeight = height * 0.5;
        LogUtil.v('ChannelDrawerPage:initState:_viewPortHeight::height=$height');
      }
      final playGroupIndex = widget.channelListModel!.playGroupIndex!;
      final playChannelIndex = widget.channelListModel!.playChannelIndex!;
      if (playGroupIndex != 0 && _scrollController.hasClients) {
        final maxScrollExtent = _scrollController.position.maxScrollExtent;
        final shouldOffset = playGroupIndex * _itemHeight - _viewPortHeight! + _itemHeight * 0.5;
        if (shouldOffset < maxScrollExtent) {
          _scrollController.jumpTo(max(0.0, shouldOffset));
        } else {
          _scrollController.jumpTo(maxScrollExtent);
        }
      }
      if (playChannelIndex != 0 && _scrollChannelController.hasClients) {
        final maxScrollExtent = _scrollChannelController.position.maxScrollExtent;
        final shouldOffset = playChannelIndex * _itemHeight - _viewPortHeight! + _itemHeight * 0.5;
        if (shouldOffset < maxScrollExtent) {
          _scrollChannelController.jumpTo(max(0.0, shouldOffset));
        } else {
          _scrollChannelController.jumpTo(maxScrollExtent);
        }
      }
      _loadEPGMsg();
    });
    super.initState();
  }

  @override
  void dispose() {
    _epgTimer?.cancel();
    _epgRequest++;
    _scrollController.dispose();
    _scrollChannelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildOpenDrawer();
  }

  Widget _buildOpenDrawer() {
    final groups = widget.channelListModel?.playList;
    if (groups == null || groups.isEmpty) return const SizedBox.shrink();
    if (_browseGroupIndex >= groups.length || _browseGroupIndex < 0) _browseGroupIndex = 0;
    double drawWidth = max(MediaQuery.of(context).size.width * 0.4 + MediaQuery.of(context).padding.left, 300);
    final screenWidth = MediaQuery.of(context).size.width;
    double egpWidth = 260.0;
    _isShowEPG = (drawWidth + egpWidth) < screenWidth;
    if (_isShowEPG && _epgData != null && _epgData!.isNotEmpty) {
      drawWidth += egpWidth;
    }
    bool isShowEpgWidget = _isShowEPG && _epgData != null && _epgData!.isNotEmpty;
    return Container(
      key: _viewPortKey,
      padding: EdgeInsets.only(left: MediaQuery.of(context).padding.left),
      width: widget.isLandscape ? drawWidth : screenWidth,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black, Colors.transparent])),
      child: Row(
        children: [
          SizedBox(
            width: 100 * context.read<ThemeProvider>().textScaleFactor,
            child: ListView.builder(
              cacheExtent: _itemHeight,
              padding: const EdgeInsets.only(bottom: 100.0),
              controller: _scrollController,
              itemBuilder: (context, index) {
                final playModel = widget.channelListModel!.playList![index];
                final title = playModel.group;
                return Builder(
                  builder: (context) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        overlayColor: isTV ? WidgetStateProperty.all(Colors.greenAccent.withValues(alpha: 0.2)) : null,
                        onTap: () {
                          if (_browseGroupIndex == index) return;
                          setState(() {
                            _browseGroupIndex = index;
                          });
                          if (_scrollChannelController.hasClients) _scrollChannelController.jumpTo(0);
                          Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                        },
                        onFocusChange: (focus) async {
                          if (focus) {
                            Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                          }
                        },
                        splashColor: Colors.white.withValues(alpha: 0.3),
                        canRequestFocus: true,
                        child: Ink(
                          width: double.infinity,
                          height: _itemHeight,
                          decoration: BoxDecoration(
                            gradient: _browseGroupIndex == index
                                ? LinearGradient(colors: [Colors.red.withValues(alpha: 0.6), Colors.red.withValues(alpha: 0.3)])
                                : null,
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              title!,
                              style: TextStyle(color: _browseGroupIndex == index ? Colors.red : Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              itemCount: widget.channelListModel?.playList?.length ?? 0,
            ),
          ),
          VerticalDivider(width: 0.1, color: Colors.white.withValues(alpha: 0.1)),
          if ((widget.channelListModel?.playList?[_browseGroupIndex].channel?.length ?? 0) > 0)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 100.0),
                cacheExtent: _itemHeight,
                controller: _scrollChannelController,
                physics: const ScrollPhysics(),
                itemBuilder: (context, index) {
                  final channel = widget.channelListModel!.playList![_browseGroupIndex].channel![index];
                  final name = channel.title;
                  final serialNum = channel.serialNum;
                  return Builder(
                    builder: (context) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          overlayColor: isTV && EnvUtil.isMobile ? WidgetStateProperty.all(Colors.greenAccent.withValues(alpha: 0.2)) : null,
                          canRequestFocus: true,
                          autofocus: isTV && EnvUtil.isMobile && _isPlayingChannel(index),
                          onTap: () async {
                            if (_isPlayingChannel(index)) {
                              Scaffold.of(context).closeDrawer();
                              return;
                            }
                            setState(() {
                              widget.channelListModel!.playGroupIndex = _browseGroupIndex;
                              widget.channelListModel!.playChannelIndex = index;
                            });
                            widget.onTapChannel?.call(channel);
                            _loadEPGMsg();
                            Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                          },
                          onFocusChange: (focus) async {
                            if (focus) {
                              Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                            }
                          },
                          splashColor: Colors.white.withValues(alpha: 0.3),
                          child: Ink(
                            width: double.infinity,
                            height: _itemHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: _isPlayingChannel(index) ? LinearGradient(colors: [Colors.red.withValues(alpha: 0.3), Colors.transparent]) : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$serialNum $name',
                                    style: TextStyle(color: _isPlayingChannel(index) ? Colors.red : Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (_isPlayingChannel(index)) SpinKitWave(size: 20, color: Colors.red.withValues(alpha: 0.8)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                itemCount: widget.channelListModel!.playList![_browseGroupIndex].channel!.length,
              ),
            ),
          if (isShowEpgWidget)
            SizedBox(
              width: egpWidth,
              child: Material(
                color: Colors.black.withValues(alpha: 0.1),
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      alignment: Alignment.center,
                      child: const Text('播放节目单', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    VerticalDivider(width: 0.1, color: Colors.white.withValues(alpha: 0.1)),
                    Flexible(
                      child: ScrollablePositionedList.builder(
                        initialScrollIndex: _selEPGIndex,
                        itemScrollController: _epgScrollController,
                        initialAlignment: 0.3,
                        physics: const ClampingScrollPhysics(),
                        padding: isTV && EnvUtil.isMobile ? EdgeInsets.only(bottom: MediaQuery.of(context).size.height) : null,
                        itemBuilder: (BuildContext context, int index) {
                          final data = _epgData![index];
                          final isSelect = index == _selEPGIndex;
                          Widget child = Container(
                            constraints: const BoxConstraints(minHeight: 40),
                            padding: const EdgeInsets.all(10),
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${data.start}-${data.end}',
                                  style: TextStyle(
                                    fontWeight: isSelect ? FontWeight.bold : FontWeight.normal,
                                    color: isSelect ? Colors.redAccent : Colors.white,
                                    fontSize: isSelect ? 17 : 15,
                                  ),
                                ),
                                Text(
                                  '${data.title}',
                                  style: TextStyle(
                                    fontWeight: isSelect ? FontWeight.bold : FontWeight.normal,
                                    color: isSelect ? Colors.redAccent : Colors.white,
                                    fontSize: isSelect ? 17 : 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (isTV && EnvUtil.isMobile) {
                            child = InkWell(
                              onTap: () {},
                              onFocusChange: (bool isFocus) {
                                if (isFocus) {
                                  _epgScrollController.scrollTo(index: index, alignment: 0.3, duration: const Duration(milliseconds: 220));
                                }
                              },
                              overlayColor: isTV && EnvUtil.isMobile ? WidgetStateProperty.all(Colors.greenAccent.withValues(alpha: 0.2)) : null,
                              child: child,
                            );
                          }
                          return child;
                        },
                        itemCount: _epgData!.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
