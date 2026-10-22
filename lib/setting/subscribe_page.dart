import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:io';

import 'package:easy_tv_live/util/date_util.dart';
import 'package:easy_tv_live/util/device_sync_util.dart';
import 'package:easy_tv_live/util/http_util.dart';
import 'package:easy_tv_live/util/log_util.dart';
import 'package:easy_tv_live/util/m3u_util.dart';
import 'package:easy_tv_live/util/remote_util.dart';
import 'package:easy_tv_live/widget/focus_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading_plus/flutter_easyloading_plus.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:sp_util/sp_util.dart';

import '../entity/sub_scribe_model.dart';
import '../generated/l10n.dart';
import '../util/env_util.dart';
import '../util/pairing_session.dart';
import '../util/lan_push_server.dart';
import '../util/source_link.dart';
import '../util/sync_payload.dart';
import '../widget/source_editor_dialog.dart';
import '../widget/pairing_code_dialog.dart';

class SubScribePage extends StatefulWidget {
  final bool isTV;
  final String? remoteIp;
  final int remotePort;

  const SubScribePage({super.key, this.isTV = false, this.remoteIp, this.remotePort = 8828});

  @override
  State<SubScribePage> createState() => _SubScribePageState();
}

class _SubScribePageState extends State<SubScribePage> {
  AppLifecycleListener? _appLifecycleListener;

  List<SubScribeModel> _m3uList = <SubScribeModel>[];

  LanPushServer? _server;
  final _pairing = PairingSession();
  Timer? _pairingTimer;
  String? _remoteToken;
  late int _remotePort = widget.remotePort;

  String? _address;
  late String? _remoteIP = widget.remoteIp;
  final _port = 8828;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _localNet();
    _pairingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    _getData();
    _pasteClipboard();
    _addLifecycleListen();
  }

  Options get _remoteOptions => Options(headers: {'X-EasyTV-Token': _remoteToken});

  Future<void> _bindRemoteIP() async {
    if (EnvUtil.isTV() || _remoteIP == null || _remoteIP == '') return;
    final code = await showDialog<String>(context: context, builder: (_) => const PairingCodeDialog());
    if (!mounted) return;
    if (code == null) {
      setState(() => _remoteIP = null);
      return;
    }
    final target = _remoteIP!;
    final response = await HttpUtil().postRequest('http://$target:$_remotePort/pair', data: {'code': code});
    if (!mounted) return;
    if (response is! Map || response['token'] is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(response['token'])) {
      setState(() => _remoteIP = null);
      EasyLoading.showToast('配对失败，请重新扫码并核对临时配对码');
      return;
    }
    _remoteToken = response['token'];
    final callbackToken = _pairing.issueToken(target);
    final bound = await HttpUtil().postRequest(
      'http://$target:$_remotePort/ip',
      data: {'port': _server!.port, 'callbackToken': callbackToken},
      options: _remoteOptions,
    );
    if (!mounted) return;
    if (bound == null) {
      _pairing.revokePeer(target);
      setState(() {
        _remoteIP = null;
        _remoteToken = null;
      });
      EasyLoading.showToast('设备连接失败');
    } else {
      setState(() {});
      EasyLoading.showToast('设备已配对');
    }
  }

  _addLifecycleListen() {
    if (EnvUtil.isTV()) return;
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        LogUtil.v('addLifecycleListen::::::$state');
        if (state == AppLifecycleState.resumed) {
          _pasteClipboard();
        }
      },
    );
  }

  _pasteClipboard() async {
    if (EnvUtil.isTV()) return;
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final clipText = clipData?.text;
    if (clipText != null && clipText.startsWith('http') && !clipText.endsWith('.json')) {
      final res = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xff3C3F41),
            title: Text(S.current.dialogTitle),
            content: Text('${S.current.dataSourceContent}\n$clipText'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(S.current.dialogCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(S.current.dialogConfirm),
              ),
            ],
          );
        },
      );
      if (res == true) {
        await _pareUrl(clipText);
      }
      Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  Future<void> _localNet() async {
    try {
      final ip = await RemoteUtil.getCurrentIP();
      if (!mounted) return;
      if (ip == null || ip.isEmpty) {
        EasyLoading.showToast('无法获取本机IP，仍可手动添加订阅源');
        return;
      }
      final server = LanPushServer(_pairing, _handlePush);
      _server = server;
      await server.start(ip, port: _port);
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() {
        _address = 'http://$ip:${server.port}';
      });
      await _bindRemoteIP();
    } catch (_) {
      if (mounted) EasyLoading.showToast('局域网推送启动失败，仍可手动添加订阅源');
    }
  }

  Future<Map<String, dynamic>> _handlePush(String path, Map<String, dynamic> data, InternetAddress peer) async {
    if (!mounted) throw StateError('Page closed');
    switch (path) {
      case '/':
        final link = data['url'];
        if (link is! String || !SourceLink.isValidSubscription(link)) throw const FormatException('Invalid URL');
        await _pareUrl(link);
        return {'message': '订阅源已接收'};
      case '/sync':
        final validated = SyncPayload.validate(data);
        await DeviceSyncUtil.applyAllSettings(context, validated);
        await _getData();
        return {'message': '同步成功'};
      case '/ip':
        final port = data['port'];
        final token = data['callbackToken'];
        if (port is! int || port < 1 || port > 65535 || token is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
          throw const FormatException('Invalid peer');
        }
        setState(() {
          _remoteIP = peer.address;
          _remotePort = port;
          _remoteToken = token;
        });
        return {'message': '设备已配对'};
      case '/exit':
        if (_remoteIP == peer.address)
          setState(() {
            _remoteIP = null;
            _remoteToken = null;
          });
        _pairing.revokePeer(peer.address);
        return {'message': '连接已断开'};
      default:
        throw const FormatException('Unknown request');
    }
  }

  _getData() async {
    final res = await M3uUtil.getLocalData();
    if (!mounted) return;
    setState(() {
      _m3uList = res;
    });
  }

  @override
  void dispose() {
    if (_remoteIP != null) unawaited(HttpUtil().postRequest('http://$_remoteIP:$_remotePort/exit', data: {}, options: _remoteOptions, isShowLoading: false));
    _pairingTimer?.cancel();
    _pairing.close();
    _appLifecycleListener?.dispose();
    _scrollController.dispose();
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isTV ? const Color(0xFF1E2022) : null,
      appBar: AppBar(
        backgroundColor: widget.isTV ? const Color(0xFF1E2022) : null,
        title: Text(S.current.subscribe),
        centerTitle: false,
        leading: widget.isTV ? const SizedBox.shrink() : null,
        actions: [
          TextButton(onPressed: _addLocalM3u, child: Text('本地添加')),
          TextButton(onPressed: _addM3uSource, child: Text('网络添加')),
        ],
      ),
      body: Column(
        children: [
          if (_address != null)
            ListTile(
              title: Text('临时配对码：${_pairing.code}（5分钟有效）'),
              subtitle: const Text('扫码后需输入此码；关闭此页后配对会话失效'),
              trailing: TextButton(
                onPressed: () => setState(() {
                  _pairing.renew();
                }),
                child: const Text('换一个码'),
              ),
            ),
          if (_m3uList.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('暂无订阅源，请添加网络源或本地文件')),
          if ((Platform.isAndroid || Platform.isIOS) && !widget.isTV && _remoteIP != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.green.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Text('设备连接成功，可以同步啦！'),
                  const Spacer(),
                  TextButton(onPressed: _showSyncBottomSheet, child: const Text('立即同步')),
                ],
              ),
            ),
          Flexible(
            child: Row(
              children: [
                SizedBox(
                  width: widget.isTV ? MediaQuery.of(context).size.width * 0.3 : MediaQuery.of(context).size.width,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    controller: _scrollController,
                    itemBuilder: (context, index) {
                      final model = _m3uList[index];
                      return Builder(
                        builder: (context) {
                          return FocusCard(
                            key: ValueKey(model.link),
                            model: model,
                            existingLinks: _m3uList.map((source) => source.link!),
                            onDelete: () async {
                              await M3uUtil.deleteSource(model.link!);
                              await _getData();
                            },
                            onUse: () async {
                              for (var element in _m3uList) {
                                element.selected = false;
                              }
                              if (model.selected != true) {
                                model.selected = true;
                                await SpUtil.remove('m3u_cache');
                                await M3uUtil.saveLocalData(_m3uList);
                                if (mounted) setState(() {});
                              }
                            },
                            onEdit: (val) async {
                              model.link = val;
                              await M3uUtil.saveLocalData(_m3uList);
                              if (mounted) setState(() {});
                            },
                          );
                        },
                      );
                    },
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 10);
                    },
                    itemCount: _m3uList.length,
                  ),
                ),
                if (widget.isTV || !EnvUtil.isMobile) const VerticalDivider(),
                if ((widget.isTV || !EnvUtil.isMobile) && (_remoteIP == null || _remoteIP == ''))
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(S.current.tvScanTip, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Container(
                            decoration: const BoxDecoration(color: Colors.white),
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.all(10),
                            width: 150,
                            child: _address == null ? null : PrettyQrView.data(data: _address!),
                          ),
                          if (_address != null) Container(margin: const EdgeInsets.only(bottom: 20), child: Text(S.current.pushAddress(_address ?? ''))),
                          Text(S.current.tvPushContent),
                        ],
                      ),
                    ),
                  ),
                if (widget.isTV && (_remoteIP != null && _remoteIP != ''))
                  Expanded(
                    child: ListView(
                      children: [
                        const Text('设备连接成功\n您可以同步下列数据到移动端：'),
                        const SizedBox(height: 12),
                        ListTile(
                          title: const Text('同步所有设置'),
                          onTap: () {
                            _syncData(0);
                          },
                        ),
                        ListTile(
                          title: const Text('同步订阅源'),
                          onTap: () {
                            _syncData(1);
                          },
                        ),
                        ListTile(
                          title: const Text('同步字体设置'),
                          onTap: () {
                            _syncData(2);
                          },
                        ),
                        ListTile(
                          title: const Text('同步美化设置'),
                          onTap: () {
                            _syncData(3);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.isTV)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(S.current.pasterContent, style: const TextStyle(color: Color(0xFF999999))),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }

  _addLocalM3u() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['m3u', 'm3u8', 'txt']);
    if (result != null) {
      File file = File(result.files.single.path!);
      LogUtil.v('添加本地订阅源::::：${file.path}');
      final hasIndex = _m3uList.indexWhere((element) => element.link == file.path);
      LogUtil.v('添加:hasIndex:::：$hasIndex');
      if (hasIndex != -1) {
        EasyLoading.showToast(S.current.addRepeat);
        return;
      }
      final sub = SubScribeModel(
        time: DateUtil.formatDate(DateTime.now(), format: DateFormats.full),
        link: file.path,
        selected: false,
        local: true,
      );
      _m3uList.add(sub);
      await M3uUtil.saveLocalData(_m3uList);
      if (!mounted) return;
      setState(() {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.positions.isNotEmpty) {
            _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          }
        });
      });
    }
  }

  Future<void> _addM3uSource() async {
    final res = await showDialog<String>(
      context: context,
      builder: (_) => SourceEditorDialog(existingLinks: _m3uList.map((source) => source.link!)),
    );
    if (!mounted || res == null) return;
    await _pareUrl(res);
  }

  _pareUrl(String res) async {
    LogUtil.v('添加网络订阅源::::：$res');
    final hasIndex = _m3uList.indexWhere((element) => element.link == res);
    LogUtil.v('添加:hasIndex:::：$hasIndex');
    if (hasIndex != -1) {
      EasyLoading.showToast(S.current.addRepeat);
      return;
    }
    if (SourceLink.isValidSubscription(res) && hasIndex == -1) {
      LogUtil.v('添加：$res');
      final sub = SubScribeModel(
        time: DateUtil.formatDate(DateTime.now(), format: DateFormats.full),
        link: res,
        selected: false,
      );
      _m3uList.add(sub);
      await M3uUtil.saveLocalData(_m3uList);
      if (!mounted) return;
      setState(() {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.positions.isNotEmpty) {
            _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          }
        });
      });
    } else {
      EasyLoading.showToast(S.current.addNoHttpLink);
    }
  }

  _showSyncBottomSheet() async {
    final res = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('数据同步', style: TextStyle(fontSize: 15)),
            ),
            const Divider(thickness: 1, height: 1),
            ListTile(
              title: const Text('同步所有设置'),
              onTap: () {
                Navigator.pop(context, 0);
              },
            ),
            ListTile(
              title: const Text('同步订阅源'),
              onTap: () {
                Navigator.pop(context, 1);
              },
            ),
            ListTile(
              title: const Text('同步字体设置'),
              onTap: () {
                Navigator.pop(context, 2);
              },
            ),
            ListTile(
              title: const Text('同步美化设置'),
              onTap: () {
                Navigator.pop(context, 3);
              },
            ),
          ],
        );
      },
    );
    if (res == null) return;
    _syncData(res);
  }

  _syncData(int type) async {
    if (_remoteIP == null || _remoteToken == null) {
      EasyLoading.showToast('请先扫码配对');
      return;
    }
    EasyLoading.show(status: '开始同步');
    Map<String, dynamic> params = switch (type) {
      0 => await DeviceSyncUtil.syncAllSettings(context),
      1 => await DeviceSyncUtil.syncVideoList(),
      2 => await DeviceSyncUtil.syncFont(context),
      3 => await DeviceSyncUtil.syncPrettify(context),
      _ => {},
    };
    if (!mounted || _remoteIP == null || _remoteToken == null) {
      EasyLoading.dismiss();
      return;
    }
    final response = await HttpUtil().postRequest('http://$_remoteIP:$_remotePort/sync', data: params, options: _remoteOptions, isShowLoading: false);
    if (response != null) {
      EasyLoading.showSuccess('同步成功');
    } else {
      if (mounted) {
        if (_remoteIP != null) _pairing.revokePeer(_remoteIP!);
        setState(() {
          _remoteIP = null;
          _remoteToken = null;
        });
      }
      EasyLoading.showToast('同步失败');
    }
  }
}
