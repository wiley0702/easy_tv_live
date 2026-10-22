import 'package:flutter/material.dart';

class PairingCodeDialog extends StatefulWidget {
  const PairingCodeDialog({super.key});
  @override
  State<PairingCodeDialog> createState() => _PairingCodeDialogState();
}

class _PairingCodeDialogState extends State<PairingCodeDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('连接设备'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: const InputDecoration(labelText: '请输入目标设备显示的临时配对码'),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      TextButton(
        onPressed: () {
          final code = _controller.text.trim();
          if (RegExp(r'^\d{6}$').hasMatch(code)) Navigator.pop(context, code);
        },
        child: const Text('配对'),
      ),
    ],
  );
}
