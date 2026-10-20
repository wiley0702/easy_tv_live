import 'package:flutter/material.dart';
import 'package:flutter_easyloading_plus/flutter_easyloading_plus.dart';

import '../util/m3u_util.dart';

class SourceRefreshTile extends StatefulWidget {
  final String link;
  const SourceRefreshTile({super.key, required this.link});

  @override
  State<SourceRefreshTile> createState() => _SourceRefreshTileState();
}

class _SourceRefreshTileState extends State<SourceRefreshTile> {
  bool _busy = false;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await M3uUtil.refreshSource(widget.link);
      EasyLoading.showToast(result == null ? '更新失败，保留原有频道和最近成功刷新时间' : '源更新成功');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = M3uUtil.lastRefreshTime(widget.link);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('更新时间：${time == null || time.isEmpty ? '尚未更新' : time}', style: const TextStyle(fontSize: 14)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            label: Text(_busy ? '更新中…' : '更新源'),
          ),
        ),
      ],
    );
  }
}
