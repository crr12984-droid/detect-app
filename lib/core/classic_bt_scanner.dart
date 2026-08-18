import 'dart:async';
import 'package:flutter/services.dart';

/// 一台经典蓝牙(BR/EDR)设备在 inquiry 中发现的结果。
class ClassicBtResult {
  final String name; // remote name request 拿到的真实名（如 "iPhone"、"AirPods"）
  final String mac; // 设备地址（经典蓝牙多为真实 MAC，非随机化）
  final int rssi; // 广播 RSSI
  final int cod; // Class of Device(24位)
  ClassicBtResult(
      {required this.name,
      required this.mac,
      required this.rssi,
      required this.cod});

  static ClassicBtResult fromMap(Map<dynamic, dynamic> m) => ClassicBtResult(
        name: (m['name'] as String?) ?? '',
        mac: (m['mac'] as String?) ?? '',
        rssi: (m['rssi'] as int?) ?? -100,
        cod: (m['cod'] as int?) ?? 0,
      );
}

/// 经典蓝牙（BR/EDR）扫描：经 Android 原生 BluetoothAdapter.startDiscovery
/// 免配对发现周边「可发现」设备，拿真实名称 + CoD。
/// 通道在 MainActivity.kt 中实现（由 ci/patch_android.py 注入）。
class ClassicBtScanner {
  static const MethodChannel _channel = MethodChannel('detect_app/classic_bt');
  static const EventChannel _events =
      EventChannel('detect_app/classic_bt/events');

  StreamSubscription? _sub;

  /// 开始 discovery，并把发现的设备回调给 [onFound]。
  /// 先订阅事件流再启动 discovery，避免事件先于监听器到达而丢失。
  Future<bool> startDiscovery(void Function(ClassicBtResult) onFound) async {
    try {
      // 先订阅（触发原生 onListen 建立 sink），再启动 discovery
      _sub?.cancel();
      _sub = _events.receiveBroadcastStream().listen((event) {
        if (event == null) return;
        try {
          onFound(ClassicBtResult.fromMap(event as Map));
        } catch (_) {}
      });
      final ok = await _channel.invokeMethod<bool>('startDiscovery');
      if (ok != true) {
        await _sub?.cancel();
        _sub = null;
        return false;
      }
    } catch (_) {
      await _sub?.cancel();
      _sub = null;
      return false;
    }
    return true;
  }

  /// 停止 discovery。
  Future<void> stopDiscovery() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel.invokeMethod('stopDiscovery');
    } catch (_) {}
  }
}
