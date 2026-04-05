import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/logger.dart';

class RemotePlay {
  DLNAManager? _searcher;
  StreamSubscription? _deviceSubscription;

  // 专门负责启动搜索的异步方法
  Future<void> _startSearch(
    String videoUrl,
    Function(void Function()) setState,
    Function(String) showToast,
    Function(String) showError,
  ) async {
    // 确保停止之前的搜索，释放资源
    await _stopSearch();

    try {
      showToast('开始搜索...');
      _searcher = DLNAManager();
      
      // 【关键修改】使用 reusePort: true 来避免端口冲突
      final dlna = await _searcher!.start(reusePort: true);
      
      final List<Widget> deviceWidgets = [];
      
      _deviceSubscription = dlna.devices.stream.listen((deviceList) {
        deviceWidgets.clear();
        deviceList.forEach((key, value) {
          KazumiLogger().i('RemotePlay: 发现设备 - ${value.info.friendlyName}');
          deviceWidgets.add(
            ListTile(
              leading: _deviceUPnPIcon(value.info.deviceType.split(':')[3]),
              title: Text(value.info.friendlyName),
              subtitle: Text(value.info.deviceType.split(':')[3]),
              onTap: () {
                try {
                  showToast('尝试投屏至 ${value.info.friendlyName}');
                  final device = DLNADevice(value.info);
                  device.setUrl(videoUrl);
                  device.play();
                } catch (e) {
                  KazumiLogger().e('RemotePlay: 投屏失败', error: e);
                  showError('DLNA 异常: $e \n请尝试重新搜索或切换设备');
                }
              },
            ),
          );
        });
        // 刷新对话框UI
        setState(() {});
      });
    } catch (e) {
      KazumiLogger().e('RemotePlay: 启动DLNA搜索失败', error: e);
      showError('启动DLNA搜索失败: $e\n请检查网络后重试');
      await _stopSearch();
    }
  }

  Future<void> _stopSearch() async {
    await _deviceSubscription?.cancel();
    _deviceSubscription = null;
    await _searcher?.stop();
    _searcher = null;
  }

  Future<void> castVideo(String video, String referer) async {
    await KazumiDialog.show(
      builder: (BuildContext context) {
        // 这个列表将由 _startSearch 方法动态填充
        List<Widget> deviceWidgets = [];
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('远程投屏'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: deviceWidgets,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => KazumiDialog.dismiss(),
                  child: Text(
                    '退出',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // 在点击搜索按钮时，调用 _startSearch 方法
                    await _startSearch(
                      video,
                      setState,
                      (msg) => KazumiDialog.showToast(message: msg),
                      (errMsg) => KazumiDialog.showToast(message: errMsg),
                    );
                  },
                  child: Text(
                    '搜索',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismiss: () {
        _stopSearch();
      },
    );
  }

  Icon _deviceUPnPIcon(String deviceType) {
    // ... 原有的图标映射逻辑保持不变 ...
    switch (deviceType) {
      case 'MediaRenderer':
        return const Icon(Icons.cast_connected);
      case 'MediaServer':
        return const Icon(Icons.cast_connected);
      case 'InternetGatewayDevice':
        return const Icon(Icons.router);
      case 'BasicDevice':
        return const Icon(Icons.device_hub);
      case 'DimmableLight':
        return const Icon(Icons.lightbulb);
      case 'WLANAccessPoint':
        return const Icon(Icons.lan);
      case 'WLANConnectionDevice':
        return const Icon(Icons.wifi_tethering);
      case 'Printer':
        return const Icon(Icons.print);
      case 'Scanner':
        return const Icon(Icons.scanner);
      case 'DigitalSecurityCamera':
        return const Icon(Icons.camera_enhance_outlined);
      default:
        return const Icon(Icons.question_mark);
    }
  }
}
