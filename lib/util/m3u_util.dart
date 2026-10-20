import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_tv_live/entity/play_channel_list_model.dart';
import 'package:easy_tv_live/util/date_util.dart';
import 'package:easy_tv_live/util/env_util.dart';
import 'package:easy_tv_live/util/http_util.dart';
import 'package:flutter/material.dart';
import 'package:sp_util/sp_util.dart';

import '../entity/sub_scribe_model.dart';
import '../generated/l10n.dart';
import '../tv/tv_setting_page.dart';
import 'log_util.dart';

class M3uUtil {
  M3uUtil._();

  static final Map<String, Channel> _serialNumMap = {};

  static Map<String, Channel> get serialNumMap => _serialNumMap;

  static String? currentPlayChannelLink = '';

  // Notify the player only after a manual refresh has been validated.
  static final refreshedPlaylist = ValueNotifier<PlayChannelListModel?>(null);

  static String _sourceKey(String link) => base64Url.encode(utf8.encode(
    link == 'default' ? 'wiley0702/easy_tv_live/default' : link,
  ));

  static String? lastRefreshTime(String link) =>
      SpUtil.getString('source_updated_${_sourceKey(link)}');

  static Future<PlayChannelListModel?> getDefaultM3uData({bool forceRefresh = false}) async {
    final models = await getLocalData();
    if (models.isEmpty) {
      models.add(SubScribeModel(
        time: DateUtil.formatDate(DateTime.now(), format: DateFormats.full),
        link: 'default', selected: true,
      ));
      await saveLocalData(models);
    }
    final source = models.firstWhere((e) => e.selected == true, orElse: () => models.first);
    final link = source.link!;
    final key = _sourceKey(link);
    final cacheKey = 'source_cache_$key';
    final ua = link.startsWith('http') ? Uri.parse(link).queryParameters['ua'] ?? '' : '';
    PlayChannelListModel? parsed;
    try {
      final String? data;
      if (source.local == true) {
        data = await File(link).readAsString();
      } else {
        data = await HttpUtil().getRequest<String>(
          link == 'default' ? EnvUtil.videoDefaultChannelHost() : link,
          isShowLoading: false,
        );
      }
      if (data != null && data.trim().isNotEmpty) {
        parsed = await _validatedPlaylist(data, ua);
        if (parsed != null) {
          // Never replace a working cache or its timestamp with invalid data.
          await SpUtil.putString(cacheKey, data);
          await SpUtil.putString('source_updated_$key',
            DateUtil.formatDate(DateTime.now(), format: DateFormats.full));
          // Retain this marker for existing source-selection/sync UI.
          await SpUtil.putString('m3u_cache', data);
        }
      }
    } catch (e) {
      LogUtil.e('Source refresh failed: $e');
    }
    if (parsed == null && !forceRefresh) {
      final cached = SpUtil.getString(cacheKey, defValue: '') ?? '';
      if (cached.isNotEmpty) {
        try {
          parsed = await _validatedPlaylist(cached, ua);
        } catch (e) {
          LogUtil.e('Source cache parse failed: $e');
        }
      }
    }
    if (parsed == null) return null;
    currentPlayChannelLink = link;
    _serialNumMap.clear();
    int serial = 1;
    for (int i = 0; i < parsed.playList!.length; i++) {
      final channels = parsed.playList![i].channel!;
      for (int j = 0; j < channels.length; j++) {
        final channel = channels[j];
        channel.serialNum = serial;
        channel.groupIndex = i;
        channel.channelIndex = j;
        _serialNumMap['$serial'] = channel;
        serial++;
      }
    }
    if (forceRefresh) refreshedPlaylist.value = parsed;
    return parsed;
  }

  static Future<PlayChannelListModel?> _validatedPlaylist(String data, String ua) async {
    final parsed = await parsePlaylist(data, ua);
    for (final group in parsed.playList!) {
      group.channel!.removeWhere((channel) => channel.urls?.isEmpty ?? true);
    }
    parsed.playList!.removeWhere((group) => group.channel!.isEmpty);
    return parsed.playList!.isEmpty ? null : parsed;
  }

  static Future<bool> isChangeChannelLink() async {
    final models = await getLocalData();
    if (models.isEmpty) return true;
    final defaultModel = models.firstWhere((element) => element.selected == true, orElse: () => models.first);
    return currentPlayChannelLink != defaultModel.link;
  }

  // 获取本地m3u数据
  static Future<List<SubScribeModel>> getLocalData() async {
    Completer completer = Completer();
    List<SubScribeModel> m3uList = SpUtil.getObjList('local_m3u', (v) => SubScribeModel.fromJson(v), defValue: <SubScribeModel>[])!;
    completer.complete(m3uList);
    final res = await completer.future;
    return res;
  }

  // 保存本地m3u数据
  static Future<bool> saveLocalData(List<SubScribeModel> models) async {
    final res = await SpUtil.putObjectList('local_m3u', models.map((e) => e.toJson()).toList());
    return res ?? false;
  }

  static bool isLiveLink(String link) {
    return RegExp(r'^(https?|rtmps?|rtsp|rtp|udp|srt|p2p|p3p|mitv|ws|wss)://',
      caseSensitive: false).hasMatch(link.trim());
  }

  // 解析m3u文件
  static Future<PlayChannelListModel> parsePlaylist(String m3u, [String ua = '']) async {
    m3u = m3u.replaceFirst('\uFEFF', '').trim();
    final lines = m3u.split('\n').map((line) => line.trim()).toList();
    PlayChannelListModel playListModel = PlayChannelListModel(type: PlayListType.txt, playList: [], uaHint: ua);
    if (m3u.startsWith('#EXTM3U') || m3u.startsWith('#EXTINF')) {
      playListModel.type = PlayListType.m3u;
      String tempGroupTitle = '';
      String tempChannelName = '';
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i];
        if (line.startsWith('#EXTM3U')) {
          List<String> params = line.replaceAll('"', '').split(' ');
          final tvgUrl = params.firstWhere((element) => element.startsWith('x-tvg-url'), orElse: () => '');
          if (tvgUrl.isNotEmpty) {
            playListModel.epgUrl = tvgUrl.split('=').last;
          }
        } else if (line.startsWith('#EXTINF:')) {
          if (line.startsWith('#EXTINF:-1,')) {
            line = line.replaceFirst('#EXTINF:-1,', '#EXTINF:-1 ');
          }
          final lineList = line.split(',');
          List<String> params = lineList.first.replaceAll('"', '').split(' ');
          final groupStr = params.firstWhere((element) => element.startsWith('group-title='), orElse: () => 'group-title=${S.current.defaultText}');
          String tvgLogo = params.firstWhere((element) => element.startsWith('tvg-logo='), orElse: () => '');
          String tvgId = params.firstWhere((element) => element.startsWith('tvg-name='), orElse: () => '');
          if (tvgId.isEmpty) {
            tvgId = params.firstWhere((element) => element.startsWith('tvg-id='), orElse: () => '');
          }
          if (tvgId.isNotEmpty) {
            tvgId = tvgId.split('=').last;
          }
          if (tvgLogo.isNotEmpty) {
            tvgLogo = tvgLogo.split('=').last;
          }
          if (groupStr.isNotEmpty) {
            tempGroupTitle = groupStr.split('=').last;
            tempChannelName = lineList.last;
            final playModel = playListModel.playList!.firstWhere(
              (model) => model.group == tempGroupTitle,
              orElse: () {
                final model = PlayModel(group: tempGroupTitle, channel: []);
                playListModel.playList!.add(model);
                return model;
              },
            );
            final channel = playModel.channel!.firstWhere(
              (element) => element.title == tempChannelName,
              orElse: () {
                final model = Channel(id: tvgId, logo: tvgLogo, title: tempChannelName, urls: []);
                playModel.channel!.add(model);
                return model;
              },
            );
            final lineNext = i + 1 < lines.length ? lines[i + 1] : '';
            if (isLiveLink(lineNext)) {
              if (lineNext.contains('#')) {
                channel.urls!.addAll(lineNext.split('#'));
              } else {
                channel.urls!.add(lineNext);
              }
              i += 1;
            } else if (i + 2 < lines.length && isLiveLink(lines[i + 2])) {
              if (lines[i + 2].contains('#')) {
                channel.urls!.addAll(lines[i + 2].split('#'));
              } else {
                channel.urls!.add(lines[i + 2].toString());
              }
              i += 2;
            }
          }
        } else if (isLiveLink(line)) {
          playListModel.playList!
              .firstWhere((model) => model.group == tempGroupTitle)
              .channel!
              .firstWhere((element) => element.title == tempChannelName)
              .urls!
              .add(line);
        } else if (line.startsWith('#UA-Hint')) {
          if (ua.isEmpty) {
            playListModel.uaHint = line.split(' ').firstWhere((item) => item.contains('/'), orElse: () => '');
          }
        }
      }
    } else {
      String tempGroup = S.current.defaultText;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineList = line.split(',');
        if (lineList.length >= 2) {
          final groupTitle = lineList[0];
          final channelLink = lineList[1];
          if (isLiveLink(channelLink)) {
            final playModel = playListModel.playList!.firstWhere(
              (model) => model.group == tempGroup,
              orElse: () {
                final model = PlayModel(group: tempGroup, channel: []);
                playListModel.playList!.add(model);
                return model;
              },
            );
            final channel = playModel.channel!.firstWhere(
              (element) => element.title == groupTitle,
              orElse: () {
                final model = Channel(id: groupTitle, title: groupTitle, urls: []);
                playModel.channel!.add(model);
                return model;
              },
            );
            if (channelLink.contains('#')) {
              channel.urls!.addAll(channelLink.split('#'));
            } else {
              channel.urls!.add(channelLink);
            }
          } else {
            tempGroup = groupTitle == '' ? '${S.current.defaultText}${i + 1}' : groupTitle;
            int index = playListModel.playList!.indexWhere((e) => e.group == tempGroup);
            if (index == -1) {
              playListModel.playList!.add(PlayModel(group: tempGroup, channel: []));
            }
          }
        }
      }
    }

    return playListModel;
  }

  static Future<bool?> openAddSource(BuildContext context) async {
    return Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const TvSettingPage();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, -1.0);
          var end = Offset.zero;
          var curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }
}
