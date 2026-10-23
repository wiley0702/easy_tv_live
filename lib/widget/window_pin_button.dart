import 'package:flutter/material.dart';
import '../util/window_pin_controller.dart';

class WindowPinButton extends StatelessWidget {
  const WindowPinButton({super.key, this.controller});
  final WindowPinController? controller;
  @override
  Widget build(BuildContext context) {
    final pin = controller ?? WindowPinController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([pin.pinned, pin.busy]),
      builder: (context, _) => IconButton(
        tooltip: '${pin.pinned.value ? '取消置顶' : '窗口置顶'} (Ctrl+Shift+T)',
        onPressed: pin.busy.value ? null : pin.toggle,
        style: IconButton.styleFrom(
          backgroundColor: pin.pinned.value
              ? Colors.orange.shade800
              : Colors.black87,
          side: const BorderSide(color: Colors.white),
        ),
        icon: Icon(
          pin.pinned.value ? Icons.push_pin : Icons.push_pin_outlined,
          color: Colors.white,
        ),
      ),
    );
  }
}
