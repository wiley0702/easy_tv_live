import 'dart:convert';
import 'dart:io';

import 'package:easy_tv_live/entity/remote_model.dart';
import 'package:easy_tv_live/provider/theme_provider.dart';
import 'package:easy_tv_live/util/log_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading_plus/flutter_easyloading_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sp_util/sp_util.dart';

import 'http_util.dart';

class RemoteUtil {
  RemoteUtil._();
  static Future<bool> getRemoteData(BuildContext context, [bool isShowLoading = true]) async {
    final themeProvider = context.read<ThemeProvider>();
    final isOpenRemoteControl = themeProvider.isOpenRemoteControl;
    if (isOpenRemoteControl) {
      LogUtil.v('请求远程配置项::::::');
      try {
        final res = await HttpUtil().getRequest(themeProvider.remoteControlLink!, isShowLoading: isShowLoading);
        Map<String, dynamic>? resJson;
        if (res is Map<String, dynamic>) {
          resJson = res;
        } else if (res is String) {
          resJson = json.decode(res) as Map<String, dynamic>?;
        } else {
          EasyLoading.showToast('远程配置无法解析');
          return false;
        }
        if (resJson != null) {
          final oldDtaId = SpUtil.getInt('remoteDtaId', defValue: -1);
          if (resJson['dtaId'] != oldDtaId) {
            LogUtil.v('开始应用远程配置项::::::');
            final remoteModel = RemoteModel.fromJson(resJson);
            await themeProvider.setRemoteData(remoteModel);
          } else {
            LogUtil.v('远程配置dtaId未变更，本次使用本地设置::::::');
          }
          return true;
        }
      } on Exception catch (e) {
        LogUtil.v('请求远程配置项失败::::::$e');
        EasyLoading.showToast(e.toString());
        return false;
      }
    } else {
      LogUtil.v('未开启远程配置::::::');
    }
    EasyLoading.dismiss();
    return false;
  }

  static bool usableIPv4(InternetAddress address) =>
      address.type == InternetAddressType.IPv4 && !address.isLoopback && address.address != '0.0.0.0' && !address.address.startsWith('169.254.');

  static String? selectIPv4(Iterable<InternetAddress> addresses) {
    final candidates = addresses.where(usableIPv4).toList();
    for (final address in candidates) {
      final octets = address.address.split('.').map(int.parse).toList();
      if (octets[0] == 10 || (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) || (octets[0] == 192 && octets[1] == 168)) return address.address;
    }
    return candidates.isEmpty ? null : candidates.first.address;
  }

  static Future<String?> getCurrentIP() async {
    String? currentIP = '';
    try {
      currentIP = await NetworkInfo().getWifiIP();
    } catch (e) {
      LogUtil.v(e.toString());
    }
    final wifi = InternetAddress.tryParse(currentIP ?? '');
    if (wifi != null && usableIPv4(wifi)) return wifi.address;
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
      interfaces.sort((a, b) {
        int score(NetworkInterface item) => RegExp(r'virtual|vmware|vbox|vethernet|docker|wsl', caseSensitive: false).hasMatch(item.name) ? 1 : 0;
        return score(a).compareTo(score(b));
      });
      currentIP = selectIPv4(interfaces.expand((interface) => interface.addresses));
    } catch (error) {
      LogUtil.v(error.toString());
    }
    return currentIP;
  }
}
