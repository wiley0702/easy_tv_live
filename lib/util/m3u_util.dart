import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_tv_live/entity/play_channel_list_model.dart';
import 'package:easy_tv_live/util/date_util.dart';
import 'package:easy_tv_live/util/http_util.dart';
import 'package:flutter/material.dart';
import 'package:sp_util/sp_util.dart';

import '../entity/sub_scribe_model.dart';
import '../generated/l10n.dart';
import '../tv/tv_setting_page.dart';
import 'log_util.dart';
import 'source_link.dart';

class M3uUtil {
  M3uUtil._();

  static final Map<String, Channel> _serialNumMap = {};

  static Map<String, Channel> get serialNumMap => _serialNumMap;

  static String? currentPlayChannelLink = '';

  // Notify the player only after a manual refresh has been validated.
  static final refreshedPlaylist = ValueNotifier<PlayChannelListModel?>(null);
  static final Map<String, int> _requestSerials = {};

  static List<Map<String, dynamic>> _storedRows() =>
      SpUtil.getObjList('local_m3u', (value) => Map<String, dynamic>.from(value), defValue: <Map<String, dynamic>>[]) ?? [];

  static String _encodedKey(String value) => base64Url.encode(utf8.encode(value));
  static String _sourceKey(String link) {
    for (final row in _storedRows()) {
      if (row['link'] == link && row['id'] is String) return _encodedKey(row['id']);
    }
    return _encodedKey(link);
  }

  static Future<List<SubScribeModel>>? _readingLocalData;

  static String? lastRefreshTime(String link) => SpUtil.getString('source_updated_${_sourceKey(link)}');

  static Future<PlayChannelListModel?> getDefaultM3uData({bool forceRefresh = false}) async {
    final models = await getLocalData();
    if (models.isEmpty) return null;
    final source = models.firstWhere((e) => e.selected == true, orElse: () => models.first);
    return _loadSource(source, forceRefresh: forceRefresh, activate: true);
  }

  static Future<PlayChannelListModel?> refreshSource(String link) async {
    final models = await getLocalData();
    final matches = models.where((source) => source.link == link);
    if (matches.isEmpty) return null;
    final active = models.firstWhere((source) => source.selected == true, orElse: () => models.first);
    return _loadSource(matches.first, forceRefresh: true, activate: active.link == link);
  }

  static Future<PlayChannelListModel?> _loadSource(SubScribeModel source, {required bool forceRefresh, required bool activate}) async {
    final link = source.link!;
    final request = (_requestSerials[link] ?? 0) + 1;
    _requestSerials[link] = request;
    final key = _sourceKey(link);
    final cacheKey = 'source_cache_$key';
    final ua = link.startsWith('http') ? Uri.parse(link).queryParameters['ua'] ?? '' : '';
    PlayChannelListModel? parsed;
    if (!forceRefresh) {
      final cached = SpUtil.getString(cacheKey, defValue: '') ?? '';
      if (cached.isNotEmpty) {
        try {
          parsed = await _validatedPlaylist(cached, ua);
        } catch (_) {
          /* Fetch a replacement below. */
        }
        if (parsed != null && await _isCurrentRequest(request, link, activate)) {
          if (activate) _activatePlaylist(parsed, link, false);
          unawaited(
            Future<void>.delayed(Duration.zero, () async {
              if (await _isCurrentRequest(request, link, activate)) {
                await _loadSource(source, forceRefresh: true, activate: activate);
              }
            }),
          );
          return parsed;
        }
      }
    }
    try {
      final String? data;
      if (source.local == true) {
        data = await File(link).readAsString();
      } else {
        data = await HttpUtil().getRequest<String>(link, isShowLoading: false);
      }
      if (data != null && data.trim().isNotEmpty) {
        parsed = await _validatedPlaylist(data, ua);
        if (parsed != null) {
          if (!await _isCurrentRequest(request, link, activate)) return null;
          // Never replace a working cache or its timestamp with invalid data.
          await SpUtil.putString(cacheKey, data);
          await SpUtil.putString('source_updated_$key', DateUtil.formatDate(DateTime.now(), format: DateFormats.full));
          // Retain this marker for existing source-selection/sync UI.
          if (activate) await SpUtil.putString('m3u_cache', data);
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
    // A completed request must not reactivate a subscription the user left.
    if (!await _isCurrentRequest(request, link, activate)) return null;
    if (!activate) return parsed;
    _activatePlaylist(parsed, link, forceRefresh);
    return parsed;
  }

  static void _activatePlaylist(PlayChannelListModel parsed, String link, bool notify) {
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
    if (notify) refreshedPlaylist.value = parsed;
  }

  static Future<bool> _isCurrentRequest(int request, String link, bool activate) async {
    final selected = await getLocalData();
    return request == _requestSerials[link] &&
        selected.any((source) => source.link == link) &&
        (!activate || selected.firstWhere((source) => source.selected == true, orElse: () => selected.first).link == link);
  }

  static Future<void> deleteSource(String link) async {
    final models = await getLocalData();
    final wasActive =
        currentPlayChannelLink == link ||
        (models.isNotEmpty && models.firstWhere((source) => source.selected == true, orElse: () => models.first).link == link);
    _requestSerials[link] = (_requestSerials[link] ?? 0) + 1;
    final key = _sourceKey(link);
    models.removeWhere((source) => source.link == link);
    await saveLocalData(models);
    await SpUtil.remove('source_cache_$key');
    await SpUtil.remove('source_updated_$key');
    if (wasActive) {
      currentPlayChannelLink = null;
      _serialNumMap.clear();
      await SpUtil.remove('m3u_cache');
      refreshedPlaylist.value = PlayChannelListModel(playList: []);
    }
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

  static Future<List<SubScribeModel>> getLocalData() {
    if (_readingLocalData != null) return _readingLocalData!;
    final future = _readLocalData();
    _readingLocalData = future;
    return future.whenComplete(() => _readingLocalData = null);
  }

  static Future<List<SubScribeModel>> _readLocalData() async {
    final rows = _storedRows();
    final models = <SubScribeModel>[];
    final ids = <String>{};
    var changed = false;
    for (final row in rows) {
      if (row['link'] == 'default') {
        changed = true;
        continue;
      }
      final source = SubScribeModel.fromJson(row);
      if (row['id'] == null || !ids.add(source.id)) {
        source.id = SubScribeModel.newId();
        ids.add(source.id);
        changed = true;
        final oldKey = _encodedKey(source.link!);
        final newKey = _encodedKey(source.id);
        for (final prefix in ['source_cache_', 'source_updated_']) {
          final value = SpUtil.getString('$prefix$oldKey');
          if (value != null && value.isNotEmpty) await SpUtil.putString('$prefix$newKey', value);
        }
      }
      models.add(source);
    }
    if (changed) await saveLocalData(models);
    return models;
  }

  static Future<bool> saveLocalData(List<SubScribeModel> models) async {
    final previous = _storedRows();
    final ids = <String>{};
    for (final source in models) {
      if (!previous.any((row) => row['id'] == source.id)) {
        final sameLink = previous.where((row) => row['link'] == source.link && row['id'] is String);
        if (sameLink.isNotEmpty) source.id = sameLink.first['id'];
      }
      if (!ids.add(source.id)) {
        source.id = SubScribeModel.newId();
        ids.add(source.id);
      }
      final before = previous.where((row) => row['id'] == source.id);
      if (before.isEmpty || before.first['link'] == source.link) continue;
      final oldLink = before.first['link'] as String;
      final sameAddress = source.local == true ? oldLink == source.link : SourceLink.configure(oldLink, '', '') == SourceLink.configure(source.link!, '', '');
      _requestSerials[oldLink] = (_requestSerials[oldLink] ?? 0) + 1;
      if (currentPlayChannelLink == oldLink && (!sameAddress || SourceLink.parameter(oldLink, 'ua') != SourceLink.parameter(source.link!, 'ua'))) {
        await SpUtil.remove('m3u_cache');
      }
      if (!sameAddress) {
        for (final prefix in ['source_cache_', 'source_updated_']) {
          await SpUtil.remove('$prefix${_encodedKey(source.id)}');
        }
      } else if (currentPlayChannelLink == oldLink && SourceLink.parameter(oldLink, 'ua') == SourceLink.parameter(source.link!, 'ua')) {
        currentPlayChannelLink = source.link;
      }
    }
    var selected = false;
    for (final source in models) {
      if (source.selected == true && !selected) {
        selected = true;
      } else {
        source.selected = false;
      }
    }
    if (models.isNotEmpty && !selected) models.first.selected = true;
    final res = await SpUtil.putObjectList('local_m3u', models.map((source) => source.toJson()).toList());
    return res ?? false;
  }

  static Future<void> replaceNetworkSources(List<SubScribeModel> incoming) async {
    final local = (await getLocalData()).where((source) => source.local == true).toList();
    if (incoming.any((source) => source.selected == true)) {
      for (final source in local) {
        source.selected = false;
      }
    }
    final models = [...local, ...incoming];
    await saveLocalData(models);
    await SpUtil.remove('m3u_cache');
    final current = currentPlayChannelLink;
    if (current != null && !models.any((source) => source.link == current)) {
      _requestSerials[current] = (_requestSerials[current] ?? 0) + 1;
      currentPlayChannelLink = null;
      _serialNumMap.clear();
      refreshedPlaylist.value = PlayChannelListModel(playList: []);
    }
  }

  static bool isLiveLink(String link) {
    return RegExp(r'^(https?|rtmps?|rtsp|rtp|udp|srt|p2p|p3p|mitv|ws|wss)://', caseSensitive: false).hasMatch(link.trim());
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
