import 'dart:async';
import 'package:easy_tv_live/channel_drawer_page.dart';
import 'package:easy_tv_live/entity/play_channel_list_model.dart';
import 'package:easy_tv_live/generated/l10n.dart';
import 'package:easy_tv_live/live_home_page.dart';
import 'package:easy_tv_live/provider/theme_provider.dart';
import 'package:easy_tv_live/util/m3u_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading_plus/flutter_easyloading_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sp_util/sp_util.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _Wakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
}

class _Player extends VideoPlayerController {
  _Player() : super.networkUrl(Uri.parse('https://example.com/fake'));
  final ready = Completer<void>();
  var disposed = false;
  var plays = 0;
  @override
  Future<void> initialize() async {
    await ready.future;
    if (!disposed) value = const VideoPlayerValue(duration: Duration(minutes: 1), size: Size(16, 9), isInitialized: true);
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play() async {
    plays++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
    await S.load(const Locale('zh', 'CN'));
    WakelockPlusPlatformInterface.instance = _Wakelock();
  });
  for (final scenario in ['switch', 'delete', 'retry', 'refresh']) {
    testWidgets('stale playback cannot act after $scenario', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final a = Channel(id: 'a', title: 'A', serialNum: 1, groupIndex: 0, channelIndex: 0, urls: ['https://example.com/a', 'https://example.com/a-fallback']);
      final b = Channel(id: 'b', title: 'B', serialNum: 2, groupIndex: 0, channelIndex: 1, urls: ['https://example.com/b']);
      final playlist = PlayChannelListModel(
        playList: [
          PlayModel(group: 'Group', channel: [a, b]),
        ],
      );
      M3uUtil.serialNumMap
        ..clear()
        ..addAll({'1': a, '2': b});
      final players = <_Player>[];
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            builder: EasyLoading.init(),
            home: LiveHomePage(
              initialPlaylist: playlist,
              controllerFactory: (_, _) {
                final player = _Player();
                players.add(player);
                return player;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(players.length, 1);
      final first = players.single;
      if (scenario == 'retry') {
        first.ready.completeError(StateError('failed first line'));
        await tester.pump();
      }
      if (scenario == 'refresh') {
        first.ready.complete();
        await tester.pump();
        await tester.pump();
        final moved = Channel(id: 'a', title: 'A', serialNum: 2, groupIndex: 0, channelIndex: 1, urls: a.urls);
        final updated = PlayChannelListModel(
          playList: [
            PlayModel(group: 'Group', channel: [b, moved]),
          ],
        );
        M3uUtil.serialNumMap
          ..clear()
          ..addAll({'1': b, '2': moved});
        M3uUtil.refreshedPlaylist.value = updated;
        await tester.pump();
        expect(updated.playChannelIndex, 1);
      } else if (scenario == 'delete') {
        M3uUtil.refreshedPlaylist.value = PlayChannelListModel(playList: []);
      } else {
        final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
        scaffold.openDrawer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        tester.widget<ChannelDrawerPage>(find.byType(ChannelDrawerPage).first).onTapChannel!(b);
      }
      await tester.pump();
      await tester.pump();
      expect(first.disposed, scenario != 'refresh');
      if (scenario != 'retry' && scenario != 'refresh') first.ready.complete();
      if (scenario != 'delete' && scenario != 'refresh') {
        expect(players.length, 2);
        players.last.ready.complete();
      }
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(first.plays, scenario == 'refresh' ? 1 : 0);
      expect(players.length, scenario == 'delete' || scenario == 'refresh' ? 1 : 2);
      if (scenario != 'delete') expect(players.last.plays, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    });
  }
}
