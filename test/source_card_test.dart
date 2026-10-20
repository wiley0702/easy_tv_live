import 'package:easy_tv_live/entity/sub_scribe_model.dart';
import 'package:easy_tv_live/generated/l10n.dart';
import 'package:easy_tv_live/widget/focus_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sp_util/sp_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
    await S.load(const Locale('zh', 'CN'));
  });

  testWidgets('active source has update and delete controls in a narrow card', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: FocusCard(
                model: SubScribeModel(link: 'https://example.com/a-very-long-source-name.txt', selected: true),
                onDelete: () => deleted = true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('更新时间：尚未更新'), findsOneWidget);
    expect(find.text('更新源'), findsOneWidget);
    expect(find.text(S.current.delete), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(S.current.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.dialogConfirm));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
}
