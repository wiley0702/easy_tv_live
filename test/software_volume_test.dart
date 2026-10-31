import 'dart:io';
import 'package:easy_tv_live/provider/theme_provider.dart';
import 'package:easy_tv_live/widget/volume_brightness_widget.dart';
import 'package:flutter/material.dart';
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
  test(
    'software volume persists, restores mute and clamps invalid values',
    () async {
      final provider = ThemeProvider();
      provider.setSoftwareVolume(0);
      expect(ThemeProvider().softwareVolume, 0);
      provider.setSoftwareVolume(0.4);
      expect(ThemeProvider().softwareVolume, 0.4);
      provider.setSoftwareVolume(2);
      expect(provider.softwareVolume, 1);
      provider.setSoftwareVolume(double.nan);
      expect(provider.softwareVolume, 1);
      provider.setSoftwareVolume(0.6, persist: false);
      expect(provider.softwareVolume, 0.6);
      expect(ThemeProvider().softwareVolume, 1);
    },
  );
  testWidgets(
    'Windows volume gesture changes app setting without system plugins',
    (tester) async {
      final provider = ThemeProvider()..setSoftwareVolume(0.8);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: VolumeBrightnessWidget()),
          ),
        ),
      );
      await tester.pump();
      final gesture = await tester.startGesture(const Offset(650, 200));
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(provider.softwareVolume, lessThan(0.8));
      expect(find.textContaining('软件音量'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(ThemeProvider().softwareVolume, provider.softwareVolume);
      expect(tester.takeException(), isNull);
    },
    skip: !Platform.isWindows,
  );
}
