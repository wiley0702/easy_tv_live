import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_tv_live/entity/sub_scribe_model.dart';
import 'package:easy_tv_live/generated/l10n.dart';
import 'package:easy_tv_live/util/m3u_util.dart';
import 'package:easy_tv_live/util/source_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sp_util/sp_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
    await S.load(const Locale('zh', 'CN'));
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('source-refresh-');
    await M3uUtil.saveLocalData([]);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('TXT without trailing newline retains the last channel', () async {
    final parsed = await M3uUtil.parsePlaylist('频道,http://example.com/live');
    expect(parsed.playList!.single.channel!.single.title, '频道');
  });

  test('empty installation never injects a built-in source', () async {
    expect(await M3uUtil.getDefaultM3uData(), isNull);
    expect(await M3uUtil.getLocalData(), isEmpty);
  });

  test('legacy built-in source is removed while preserving user subscriptions', () async {
    await M3uUtil.saveLocalData([SubScribeModel(link: 'default', selected: true), SubScribeModel(link: 'https://example.com/user.txt')]);
    final sources = await M3uUtil.getLocalData();
    expect(sources.single.link, 'https://example.com/user.txt');
    expect(sources.single.selected, isTrue);
  });

  test('refreshing an inactive source updates only its own cache and timestamp', () async {
    final a = File('${directory.path}/a.txt');
    final b = File('${directory.path}/b.txt');
    await a.writeAsString('A,http://example.com/a');
    await b.writeAsString('B,http://example.com/b');
    await M3uUtil.saveLocalData([SubScribeModel(link: a.path, local: true, selected: true), SubScribeModel(link: b.path, local: true)]);
    final active = await M3uUtil.getDefaultM3uData(forceRefresh: true);
    expect(await M3uUtil.refreshSource(b.path), isNotNull);
    expect(M3uUtil.lastRefreshTime(b.path), isNotEmpty);
    expect(M3uUtil.currentPlayChannelLink, a.path);
    expect(M3uUtil.serialNumMap['1']!.title, 'A');
    expect(M3uUtil.refreshedPlaylist.value, same(active));
    await M3uUtil.saveLocalData([SubScribeModel(link: b.path, local: true, selected: true)]);
    await b.delete();
    final cached = await M3uUtil.getDefaultM3uData();
    expect(cached!.playList!.single.channel!.single.title, 'B');
  });

  test('deleting the active source clears playback and deleting the last leaves no default', () async {
    final a = File('${directory.path}/a.txt');
    await a.writeAsString('A,http://example.com/a');
    await M3uUtil.saveLocalData([SubScribeModel(link: a.path, local: true, selected: true), SubScribeModel(link: 'https://example.com/b.txt')]);
    await M3uUtil.getDefaultM3uData(forceRefresh: true);
    await M3uUtil.deleteSource(a.path);
    expect(M3uUtil.serialNumMap, isEmpty);
    expect(M3uUtil.refreshedPlaylist.value!.playList, isEmpty);
    expect(M3uUtil.lastRefreshTime(a.path), anyOf(isNull, isEmpty));
    final remaining = await M3uUtil.getLocalData();
    expect(remaining.single.selected, isTrue);
    await M3uUtil.deleteSource(remaining.single.link!);
    expect(await M3uUtil.getDefaultM3uData(), isNull);
    expect(await M3uUtil.getLocalData(), isEmpty);
    expect(await M3uUtil.refreshSource(a.path), isNull);
  });

  test('truncated M3U metadata does not read past the end', () async {
    final parsed = await M3uUtil.parsePlaylist('#EXTM3U\n#EXTINF:-1,频道');
    expect(parsed.playList!.single.channel!.single.urls, isEmpty);
  });

  test('failed refresh preserves timestamp, active list and valid cache', () async {
    final file = File('${directory.path}/live.txt');
    await file.writeAsString('频道,http://example.com/live');
    await M3uUtil.saveLocalData([SubScribeModel(link: file.path, local: true, selected: true)]);
    final first = await M3uUtil.getDefaultM3uData(forceRefresh: true);
    expect(first, isNotNull);
    final updated = M3uUtil.lastRefreshTime(file.path);
    expect(updated, isNotEmpty);
    await file.writeAsString('<html>Bad gateway</html>');
    expect(await M3uUtil.getDefaultM3uData(forceRefresh: true), isNull);
    expect(M3uUtil.lastRefreshTime(file.path), updated);
    expect(M3uUtil.refreshedPlaylist.value, same(first));
    expect(M3uUtil.serialNumMap['1']!.title, '频道');
    final cached = await M3uUtil.getDefaultM3uData();
    expect(cached!.playList!.single.channel!.single.title, '频道');
    expect(M3uUtil.lastRefreshTime(file.path), updated);
  });

  test('a different source never falls back to the previous source cache', () async {
    final a = File('${directory.path}/a.txt');
    final b = File('${directory.path}/b.txt');
    await a.writeAsString('A,http://example.com/a');
    await M3uUtil.saveLocalData([SubScribeModel(link: a.path, local: true, selected: true)]);
    expect(await M3uUtil.getDefaultM3uData(), isNotNull);
    await M3uUtil.saveLocalData([SubScribeModel(link: b.path, local: true, selected: true)]);
    expect(await M3uUtil.getDefaultM3uData(), isNull);
    expect(M3uUtil.lastRefreshTime(b.path), anyOf(isNull, isEmpty));
  });

  test('a deleted source cannot be restored by a delayed refresh', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final requested = Completer<void>();
      final respond = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final link = 'http://127.0.0.1:${server.port}/deleted.txt';
      server.listen((request) async {
        requested.complete();
        await respond.future;
        request.response.write('A,http://example.com/a');
        await request.response.close();
      });
      try {
        await M3uUtil.saveLocalData([SubScribeModel(link: link, selected: true)]);
        final pending = M3uUtil.refreshSource(link);
        await requested.future.timeout(const Duration(seconds: 10));
        await M3uUtil.deleteSource(link);
        respond.complete();
        expect(await pending, isNull);
        expect(await M3uUtil.getLocalData(), isEmpty);
        expect(M3uUtil.lastRefreshTime(link), anyOf(isNull, isEmpty));
        expect(M3uUtil.serialNumMap, isEmpty);
      } finally {
        if (!respond.isCompleted) respond.complete();
        await server.close(force: true);
      }
    }, _RealHttpOverrides());
  });

  test('a delayed refresh cannot overwrite a newly selected source', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final requested = Completer<void>();
      final respond = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final link = 'http://127.0.0.1:${server.port}/a.txt';
      server.listen((request) async {
        requested.complete();
        await respond.future;
        request.response.write('A,http://example.com/a');
        await request.response.close();
      });
      try {
        final b = File('${directory.path}/b.txt');
        await b.writeAsString('B,http://example.com/b');
        await M3uUtil.saveLocalData([SubScribeModel(link: link, selected: true)]);
        final oldRequest = M3uUtil.getDefaultM3uData(forceRefresh: true);
        await requested.future.timeout(const Duration(seconds: 10));
        await M3uUtil.saveLocalData([SubScribeModel(link: b.path, local: true, selected: true)]);
        final current = await M3uUtil.getDefaultM3uData(forceRefresh: true);
        respond.complete();
        expect(await oldRequest, isNull);
        expect(M3uUtil.currentPlayChannelLink, b.path);
        expect(M3uUtil.serialNumMap['1']!.title, 'B');
        expect(M3uUtil.refreshedPlaylist.value, same(current));
        expect(M3uUtil.lastRefreshTime(link), anyOf(isNull, isEmpty));
      } finally {
        if (!respond.isCompleted) respond.complete();
        await server.close(force: true);
      }
    }, _RealHttpOverrides());
  });
  test('legacy caches migrate to stable ID and survive metadata-only edits', () async {
    const link = 'https://example.com/live?tl=Old&ua=Agent';
    final legacy = base64Url.encode(utf8.encode(link));
    await SpUtil.putObjectList('local_m3u', [
      {'link': link, 'selected': true},
    ]);
    await SpUtil.putString('source_cache_$legacy', 'A,http://example.com/a');
    await SpUtil.putString('source_updated_$legacy', '2026-10-22 10:00:00');
    final source = (await M3uUtil.getLocalData()).single;
    final id = source.id;
    expect(M3uUtil.lastRefreshTime(link), '2026-10-22 10:00:00');
    source.link = SourceLink.configure(link, 'New', 'Changed Agent');
    await M3uUtil.saveLocalData([source]);
    expect((await M3uUtil.getLocalData()).single.id, id);
    expect(M3uUtil.lastRefreshTime(source.link!), '2026-10-22 10:00:00');
    final key = base64Url.encode(utf8.encode(id));
    expect(SpUtil.getString('source_cache_$key'), 'A,http://example.com/a');
    source.link = 'https://other.example.com/live';
    await M3uUtil.saveLocalData([source]);
    expect(M3uUtil.lastRefreshTime(source.link!), anyOf(isNull, isEmpty));
    expect(SpUtil.getString('source_cache_$key'), anyOf(isNull, isEmpty));
  });

  test('cached startup returns before network completes and refreshes in background', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final requested = Completer<void>();
      final respond = Completer<void>();
      final refreshed = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final source = SubScribeModel(link: 'http://127.0.0.1:${server.port}/cached.txt', selected: true);
      await M3uUtil.saveLocalData([source]);
      await SpUtil.putString('source_cache_${base64Url.encode(utf8.encode(source.id))}', 'Cached,http://example.com/cached');
      void onRefresh() {
        if (!refreshed.isCompleted) refreshed.complete();
      }

      M3uUtil.refreshedPlaylist.addListener(onRefresh);
      server.listen((request) async {
        if (!requested.isCompleted) requested.complete();
        await respond.future;
        request.response.write('Fresh,http://example.com/fresh');
        await request.response.close();
      });
      try {
        final result = await M3uUtil.getDefaultM3uData().timeout(const Duration(seconds: 2));
        expect(result!.playList!.single.channel!.single.title, 'Cached');
        await requested.future.timeout(const Duration(seconds: 10));
        respond.complete();
        await refreshed.future.timeout(const Duration(seconds: 10));
        expect(M3uUtil.serialNumMap['1']!.title, 'Fresh');
      } finally {
        if (!respond.isCompleted) respond.complete();
        M3uUtil.refreshedPlaylist.removeListener(onRefresh);
        await server.close(force: true);
      }
    }, _RealHttpOverrides());
  });
  test('network sync preserves local files and clears removed network playback', () async {
    final local = SubScribeModel(link: '${directory.path}/local.txt', local: true);
    final network = SubScribeModel(link: 'https://example.com/network', selected: true);
    await M3uUtil.saveLocalData([local, network]);
    M3uUtil.currentPlayChannelLink = network.link;
    await M3uUtil.replaceNetworkSources([]);
    final remaining = await M3uUtil.getLocalData();
    expect(remaining.single.id, local.id);
    expect(remaining.single.selected, isTrue);
    expect(M3uUtil.currentPlayChannelLink, isNull);
    expect(M3uUtil.refreshedPlaylist.value!.playList, isEmpty);
  });
}

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context);
}
