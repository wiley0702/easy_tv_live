import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading_plus/flutter_easyloading_plus.dart';
import 'package:window_manager/window_manager.dart';

class WindowPinController {
  WindowPinController({
    required this.read,
    required this.write,
    required this.notify,
  });
  static final instance = WindowPinController(
    read: windowManager.isAlwaysOnTop,
    write: windowManager.setAlwaysOnTop,
    notify: (message) => EasyLoading.showToast(message),
  );
  final Future<bool> Function() read;
  final Future<void> Function(bool) write;
  final void Function(String) notify;
  final pinned = ValueNotifier(false);
  final busy = ValueNotifier(false);

  Future<void> toggle() async {
    if (busy.value) return;
    busy.value = true;
    try {
      final target = !await read();
      await write(target);
      pinned.value = await read();
      notify(pinned.value ? '窗口已置顶' : '已取消置顶');
    } catch (_) {
      notify('置顶切换失败，请重试');
    } finally {
      busy.value = false;
    }
  }

  bool handleKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyT ||
        !keyboard.isControlPressed ||
        !keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed)
      return false;
    unawaited(toggle());
    return true;
  }
}
