import 'dart:async';
import 'package:easy_tv_live/util/window_pin_controller.dart';
import 'package:easy_tv_live/widget/window_pin_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('button toggles actual state and shows the matching icon', (
    tester,
  ) async {
    var actual = false;
    final messages = <String>[];
    final pin = WindowPinController(
      read: () async => actual,
      write: (value) async {
        actual = value;
      },
      notify: messages.add,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WindowPinButton(controller: pin)),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(actual, isTrue);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(messages.last, '窗口已置顶');
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(actual, isFalse);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  test(
    'overlapping requests are ignored and errors release the busy state',
    () async {
      final gate = Completer<void>();
      var writes = 0;
      final messages = <String>[];
      final pin = WindowPinController(
        read: () async => false,
        write: (_) async {
          writes++;
          await gate.future;
          throw StateError('failed');
        },
        notify: messages.add,
      );
      final first = pin.toggle();
      await pin.toggle();
      gate.complete();
      await first;
      expect(writes, 1);
      expect(pin.busy.value, isFalse);
      expect(pin.pinned.value, isFalse);
      expect(messages.single, contains('失败'));
    },
  );

  testWidgets('shortcut requires Ctrl Shift T and ignores key repeat', (
    tester,
  ) async {
    var actual = false;
    var writes = 0;
    final pin = WindowPinController(
      read: () async => actual,
      write: (value) async {
        actual = value;
        writes++;
      },
      notify: (_) {},
    );
    HardwareKeyboard.instance.addHandler(pin.handleKey);
    try {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      expect(writes, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyT);
      await tester.pump();
      expect(actual, isTrue);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyT);
      await tester.pump();
      expect(writes, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    } finally {
      HardwareKeyboard.instance.removeHandler(pin.handleKey);
    }
  });
}
