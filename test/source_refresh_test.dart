import 'dart:async';
import 'dart:io';

import 'package:easy_tv_live/entity/sub_scribe_model.dart';
import 'package:easy_tv_live/generated/l10n.dart';
import 'package:easy_tv_live/util/m3u_util.dart';
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
  });
  tearDown(() async => directory.delete(recursive: true));

  test('TXT without trailing newline retains the last channel', () async {
    final parsed = await M3uUtil.parsePlaylist('频道,http://example.com/live');
    expect(parsed.playList!.single.channel!.single.title, '频道');
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
}

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context);
}
