import 'package:flutter/material.dart';
import '../util/source_link.dart';

class SourceEditorDialog extends StatefulWidget {
  final String initialLink;
  final Iterable<String> existingLinks;
  const SourceEditorDialog({super.key, this.initialLink = '', this.existingLinks = const []});

  @override
  State<SourceEditorDialog> createState() => _SourceEditorDialogState();
}

class _SourceEditorDialogState extends State<SourceEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _url = TextEditingController(text: widget.initialLink);
  late final _title = TextEditingController(text: SourceLink.parameter(widget.initialLink, 'tl') ?? '');
  late final _ua = TextEditingController(text: SourceLink.parameter(widget.initialLink, 'ua') ?? '');

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _ua.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialLink.isEmpty ? '添加网络源' : '编辑网络源'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('source-url'),
                controller: _url,
                autofocus: true,
                decoration: const InputDecoration(labelText: '订阅地址', hintText: 'https://example.com/live.m3u'),
                onChanged: (value) {
                  _title.text = SourceLink.parameter(value.trim(), 'tl') ?? '';
                  _ua.text = SourceLink.parameter(value.trim(), 'ua') ?? '';
                },
                validator: (value) {
                  if (!SourceLink.isValid(value?.trim() ?? '')) return '请输入有效的 HTTP 或 HTTPS 地址';
                  final link = SourceLink.configure(value!.trim(), _title.text, _ua.text);
                  if (link != widget.initialLink && widget.existingLinks.contains(link)) return '该订阅源已存在';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('source-title'),
                controller: _title,
                decoration: const InputDecoration(labelText: '显示标题（选填）', helperText: '留空时使用地址中的文件名'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('source-ua'),
                controller: _ua,
                decoration: const InputDecoration(labelText: 'User-Agent（选填）', helperText: '用于视频播放；留空时沿用源文件提示或播放器默认值'),
                validator: (value) => (value ?? '').contains(RegExp(r'[\r\n]')) ? 'User-Agent 不能包含换行' : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) Navigator.pop(context, SourceLink.configure(_url.text.trim(), _title.text, _ua.text));
        },
        child: const Text('保存'),
      ),
    ],
  );
}
