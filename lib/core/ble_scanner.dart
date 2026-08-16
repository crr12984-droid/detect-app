import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/device.dart';
import 'brand_db.dart';

/// 真实蓝牙低功耗（BLE）扫描：读取周边广播设备（名称、MAC、信号）。
class BleScanner {
  Future<bool> get supported async => FlutterBluePlus.isSupported;

  Stream<List<Device>> scan({Duration timeout = const Duration(seconds: 4)}) async* {
    if (!(await FlutterBluePlus.isSupported)) return;
    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );
    } catch (_) {
      return;
    }
    await for (final results in FlutterBluePlus.scanResults) {
      yield results.map((r) {
        final mac = r.device.remoteId.str.toUpperCase();
        final b = brandFromMac(mac);
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : '(未知设备)';
        return Device(
          kind: DeviceKind.ble,
          id: mac,
          name: name,
          brand: b['brand'] as String,
          domestic: b['domestic'] as bool,
          rssi: r.rssi,
        );
      }).toList();
    }
  }
}
