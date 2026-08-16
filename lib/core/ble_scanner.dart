import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/device.dart';
import 'device_classifier.dart';

/// 真实蓝牙低功耗（BLE）扫描：读取周边广播设备（名称、MAC、信号）。
/// 品牌识别依据广播包：Company ID（制造商数据）→ 名称 → Service UUID → OUI 兜底，
/// 不依赖随机化的 MAC，从而正确识别 Apple/华为/小米等真实品牌。
class BleScanner {
  // 缓存 BluetoothDevice，供后续连接读取精确型号（GATT）使用。
  final Map<String, BluetoothDevice> _devices = {};

  Future<bool> get supported async => FlutterBluePlus.isSupported;

  BluetoothDevice? deviceFor(String id) => _devices[id.toUpperCase()];

  /// 将一轮扫描结果映射为 Device（识别品牌/类别/型号，并缓存 BluetoothDevice）
  List<Device> mapResults(List<ScanResult> results) {
    return results.map((r) {
      final mac = r.device.remoteId.str.toUpperCase();
      _devices[mac] = r.device;
      final adv = r.advertisementData;
      final name = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : (adv.advName.isNotEmpty ? adv.advName : '');
      final companyId = adv.manufacturerData.isNotEmpty
          ? adv.manufacturerData.keys.first
          : null;
      final uuids = adv.serviceUuids.map((g) => g.str).toList();
      final id = classifyBle(
          mac: mac, name: name, companyId: companyId, serviceUuids: uuids);
      return Device(
        kind: DeviceKind.ble,
        id: mac,
        name: name.isEmpty ? '(未知设备)' : name,
        brand: id.brand,
        domestic: id.domestic,
        rssi: r.rssi,
        category: id.category,
        model: id.model,
        seized: false,
      );
    }).toList();
  }

  Stream<List<Device>> scan(
      {Duration timeout = const Duration(seconds: 4)}) async* {
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
      yield mapResults(results);
    }
  }
}
