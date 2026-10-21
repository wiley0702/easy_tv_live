import 'package:easy_tv_live/channel_drawer_page.dart';
import 'package:easy_tv_live/entity/play_channel_list_model.dart';
import 'package:easy_tv_live/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sp_util/sp_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
  });

  testWidgets('group browsing keeps playback; clicking a channel commits both indices', (tester) async {
    tester.view.physicalSize = const Size(540, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final a = Channel(title: 'A', serialNum: 1, groupIndex: 0, channelIndex: 0);
    final b = Channel(title: 'B', serialNum: 2, groupIndex: 1, channelIndex: 0);
    final model = PlayChannelListModel(
      playList: [
        PlayModel(group: 'Group A', channel: [a]),
        PlayModel(group: 'Group B', channel: [b]),
        PlayModel(group: 'Empty', channel: []),
      ],
    );
    final played = <Channel?>[];
    final scaffold = GlobalKey<ScaffoldState>();
    var opened = false;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) => Scaffold(
              key: scaffold,
              drawer: ChannelDrawerPage(channelListModel: model, onTapChannel: played.add, isOpen: opened),
              onDrawerChanged: (value) => update(() => opened = value),
            ),
          ),
        ),
      ),
    );
    scaffold.currentState!.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('Group B'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2 B'), findsOneWidget);
    expect(played, isEmpty);
    expect(model.playGroupIndex, 0);
    expect(model.playChannelIndex, 0);
    expect(find.byType(SpinKitWave), findsNothing);

    // Closing and reopening discards the browsing position, keeping playback.
    scaffold.currentState!.closeDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    scaffold.currentState!.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('1 A'), findsOneWidget);
    expect(find.byType(SpinKitWave), findsOneWidget);
    await tester.tap(find.text('Empty'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(played, isEmpty);
    expect(model.playGroupIndex, 0);
    await tester.tap(find.text('Group B'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('2 B'));
    await tester.pump();
    expect(played, [b]);
    expect(model.playGroupIndex, 1);
    expect(model.playChannelIndex, 0);
    expect(find.byType(SpinKitWave), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
