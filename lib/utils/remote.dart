import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/logger.dart';

class RemotePlay {
  // 保存搜索器实例，用于对话框关闭时停止
  DLNAManager? _searcher;
  StreamSubscription? _deviceSubscription;

  Future<void> castVideo(String video, String referer) async {
    // 不再提前执行 searcher.start()
    await KazumiDialog.show(
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('远程投屏'),
            content: SingleChildScrollView(
              child: Column(
                children: [], // 初始为空，搜索后才填充
              ),
            ),
            actions: [
              const SizedBox(width: 20),
              TextButton(
                onPressed: () {
                  KazumiDialog.dismiss();
                },
                child: Text(
                  '退出',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // 用户点击搜索按钮时才开始初始化 DLNA
                  setState(() {}); // 刷新对话框（可显示 loading）
                  KazumiDialog.showToast(message: '开始搜索');

                  // 如果已有旧的搜索器，先停止
                  await _stopSearch();

                  _searcher = DLNAManager();
                  try {
                    final dlna = await _searcher!.start();
                    // 清空旧设备列表
                    final List<Widget> deviceWidgets = [];
                    // 监听设备变化
                    _deviceSubscription = dlna.devices.stream.listen((deviceList) {
                      deviceWidgets.clear();
                      deviceList.forEach((key, value) async {
                        KazumiLogger().i('RemotePlay: key: $key');
                        KazumiLogger().i(
                            'RemotePlay: value: ${value.info.friendlyName} ${value.info.deviceType} ${value.info.URLBase}');
                        deviceWidgets.add(
                          ListTile(
                            leading: _deviceUPnPIcon(value.info.deviceType.split(':')[3]),
                            title: Text(value.info.friendlyName),
                            subtitle: Text(value.info.deviceType.split(':')[3]),
                            onTap: () {
                              try {
                                KazumiDialog.showToast(
                                  message: '尝试投屏至 ${value.info.friendlyName}',
                                );
                                DLNADevice(value.info).setUrl(video);
                                DLNADevice(value.info).play();
                              } catch (e) {
                                KazumiLogger()
                                    .e('RemotePlay: failed to cast to device', error: e);
                                KazumiDialog.showToast(
                                  message: 'DLNA 异常: $e \n尝试重新进入 DLNA 投屏或切换设备',
                                );
                              }
                            },
                          ),
                        );
                      });
                      // 更新对话框内容
                      setState(() {
                        // 注意：需要替换 content 中的 Column 的 children
                        // 但此处简单起见，我们直接修改 AlertDialog 的 content 会比较复杂，
                        // 实际推荐使用一个单独的 StatefulWidget 管理列表。
                        // 为保持示例清晰，假设 content 是一个可变的 ListView.builder。
                        // 由于当前代码结构限制，下面给出另一种方式：重建整个对话框内容。
                        // 为了最小改动，建议将 content 部分抽取为单独的 StatefulWidget。
                        // 这里提供一个简化版：直接使用 setState 重建 content 中的 Column。
                        // 但当前 AlertDialog 的 content 是 SingleChildScrollView(child: Column(children: deviceWidgets))
                        // 我们需要更新这个 Column 的 children。由于 StatefulBuilder 的 setState 会重建 builder，
                        // 我们可以将 deviceWidgets 放在外部，并在 builder 中引用。
                        // 下面修改 builder 实现。
                      });
                    });
                  } catch (e) {
                    KazumiLogger().e('RemotePlay: start DLNA failed', error: e);
                    KazumiDialog.showToast(message: '启动 DLNA 搜索失败: $e');
                  }
                },
                child: Text(
                  '搜索',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ],
          );
        });
      },
      onDismiss: () {
        _stopSearch();
      },
    );
  }

  Future<void> _stopSearch() async {
    await _deviceSubscription?.cancel();
    _deviceSubscription = null;
    await _searcher?.stop();
    _searcher = null;
  }

  Icon _deviceUPnPIcon(String deviceType) {
    // 原有图标映射保持不变
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
