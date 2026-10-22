import 'dart:async';
import 'dart:io';

import 'package:easy_tv_live/util/env_util.dart';
import 'package:easy_tv_live/util/remote_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading_plus/flutter_easyloading_plus.dart';
import 'package:gap/gap.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:provider/provider.dart';

import '../provider/theme_provider.dart';
import '../util/lan_push_server.dart';
import '../util/pairing_session.dart';
import '../util/source_link.dart';

class SettingRemote extends StatefulWidget {
  const SettingRemote({super.key});

  @override
  State<SettingRemote> createState() => _SettingRemoteState();
}

class _SettingRemoteState extends State<SettingRemote> {
  LanPushServer? _server;
  final _pairing = PairingSession();
  Timer? _pairingTimer;

  String? _address;
  final _port = 9928;

  late final _controller = TextEditingController(
    text: context.read<ThemeProvider>().remoteControlLink ?? '',
  );

  Future<void> _localNet() async {
    if (!EnvUtil.isTV()) return;
    try {
      final ip = await RemoteUtil.getCurrentIP();
      if (!mounted) return;
      if (ip == null || ip.isEmpty) {
        EasyLoading.showToast('无法获取本机IP');
        return;
      }
      final server = LanPushServer(_pairing, _handlePush, sourceTitle: '远程配置项');
      _server = server;
      await server.start(ip, port: _port);
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() {
        _address = 'http://$ip:${server.port}/?mode=remote-config';
      });
    } catch (_) {
      if (mounted) EasyLoading.showToast('远程配置推送启动失败');
    }
  }

  Future<Map<String, dynamic>> _handlePush(
    String path,
    Map<String, dynamic> data,
    InternetAddress peer,
  ) async {
    if (!mounted) throw StateError('Page closed');
    final url = data['url'];
    if (path != '/' || url is! String || !SourceLink.isValid(url))
      throw const FormatException('Invalid remote configuration URL');
    context.read<ThemeProvider>().setRemoteControlLink(url);
    _controller.text = url;
    final applied = await _applyRemoteSetting();
    return {'message': applied ? '应用配置成功' : '配置地址已保存，但应用失败，请检查地址内容'};
  }

  Future<bool> _applyRemoteSetting() async {
    if (!mounted) return false;
    EasyLoading.show(status: '处理远程配置');
    try {
      final applied = await RemoteUtil.getRemoteData(context, false);
      EasyLoading.dismiss();
      if (mounted) {
        if (applied)
          EasyLoading.showSuccess('应用配置成功');
        else
          EasyLoading.showError('远程配置未能应用');
      }
      return applied;
    } catch (_) {
      EasyLoading.dismiss();
      if (mounted) EasyLoading.showError('远程配置无效');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _localNet();
    _pairingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pairingTimer?.cancel();
    _pairing.close();
    _server?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showQR = EnvUtil.isTV() && _address != null;
    final querySize = MediaQuery.of(context).size;
    final isHorizontal = querySize.width > querySize.height;
    return Scaffold(
      appBar: isHorizontal
          ? null
          : AppBar(title: const Text('远程配置'), centerTitle: false),
      backgroundColor: isHorizontal ? const Color(0xFF1E2022) : null,
      body: SingleChildScrollView(
        child: Consumer<ThemeProvider>(
          builder:
              (
                BuildContext context,
                ThemeProvider themeProvider,
                Widget? child,
              ) {
                return Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        child: Text(
                          themeProvider.isOpenRemoteControl
                              ? '远程配置已生效，远程配置修改后将会覆盖应用内设置，请知悉'
                              : '',
                          style: TextStyle(fontSize: 18, color: Colors.red),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: TextField(
                              controller: _controller,
                              canRequestFocus: !EnvUtil.isTV(),
                              maxLines: 1,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.justify,
                              decoration: const InputDecoration(
                                hintText: '请输入远程配置地址',
                                labelText: '远程配置地址',
                              ),
                              onChanged: (val) {
                                if (val.isEmpty) {
                                  themeProvider.setRemoteControlLink('');
                                }
                              },
                            ),
                          ),
                          Gap(20),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  final url = _controller.text.trim();
                                  if (url.isNotEmpty) {
                                    if (SourceLink.isValid(url)) {
                                      themeProvider.setRemoteControlLink(url);
                                      _applyRemoteSetting();
                                    } else {
                                      EasyLoading.showToast('请输入可访问的http链接');
                                    }
                                  } else {
                                    EasyLoading.showToast('请输入远程配置地址');
                                  }
                                },
                                child: Text('应用远程配置'),
                              ),
                              Gap(20),
                              if (themeProvider.isOpenRemoteControl)
                                ElevatedButton(
                                  onPressed: () {
                                    themeProvider.setRemoteControlLink('');
                                    _controller.text = '';
                                  },
                                  child: Text('删除远程配置'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Gap(50),
                      if (showQR)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '手机扫描下方二维码，输入临时配对码后推送',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text('临时配对码：${_pairing.code}（5分钟有效）'),
                            TextButton(
                              onPressed: () => setState(() {
                                _pairing.renew();
                              }),
                              child: const Text('换一个码'),
                            ),
                            Gap(10),
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                              ),
                              margin: const EdgeInsets.all(10),
                              padding: const EdgeInsets.all(10),
                              width: 150,
                              child: _address == null
                                  ? null
                                  : PrettyQrView.data(data: _address!),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
        ),
      ),
    );
  }
}
