import 'package:easy_tv_live/util/source_link.dart';
import 'package:easy_tv_live/widget/source_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('metadata preserves signed query bytes, duplicate parameters and fragment', () {
    const original = 'https://example.com/a?token=a%2Fb%20c&x=1&x=2&tl=old&ua=old#section';
    final result = SourceLink.configure(original, '中文 & 标题', 'Agent/1.0 (+test)');
    expect(result, startsWith('https://example.com/a?token=a%2Fb%20c&x=1&x=2&'));
    expect(result, endsWith('#section'));
    expect(SourceLink.parameter(result, 'tl'), '中文 & 标题');
    expect(SourceLink.parameter(result, 'ua'), 'Agent/1.0 (+test)');
    expect(SourceLink.configure(result, '', ''), 'https://example.com/a?token=a%2Fb%20c&x=1&x=2#section');
    expect(SourceLink.isValid('file:///test'), isFalse);
    expect(SourceLink.isValid('https://example.com/?a=%ZZ'), isFalse);
  });

  testWidgets('paste fills fields, edit and clear metadata before saving', (tester) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showDialog<String>(context: context, builder: (_) => const SourceEditorDialog());
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('source-url')), 'https://example.com/a?token=x&tl=Old&ua=Agent%2F1');
    await tester.pump();
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('Agent/1'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('source-title')), 'New');
    await tester.enterText(find.byKey(const Key('source-ua')), '');
    await tester.enterText(find.byKey(const Key('source-url')), 'https://example.com/new-address?token=y&tl=Ignored&ua=Ignored');
    await tester.pump();
    expect(find.text('New'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved, 'https://example.com/new-address?token=y&tl=New');
  });
}
