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
      final companyId = adv.manufacturerData.isNotEmpty
          ? adv.manufacturerData.keys.first
          : null;
      final uuids = adv.serviceUuids.map((g) => g.str).toList();
      // 解析广播原始字节：Appearance(0x19)/Flags(0x01)/TxPower(0x0A)
      // （对齐 gap_le_advertisements.c；免连接即得品类/类型，解决 iOS 拒连盲区）
      final raw = adv.rawData;
      final ad = raw != null ? parseAdvertisingData(raw) : <int, List<int>>{};
      final appearance = adAppearance(ad);
      final flags = adFlags(ad);
      final txPower = adv.txPowerLevel ?? adTxPower(ad);
      // 优先取广播名称：平台名 → 广播 advName
      final rawName = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : (adv.advName.isNotEmpty ? adv.advName : '');
      // 苹果未配对时广播的是随机 base64 串，不是真实名 → 视作无名，走品牌/品类兜底
      final advName = looksLikeRandomName(rawName) ? '' : rawName;
      final id = classifyBle(
          mac: mac,
          name: advName,
          companyId: companyId,
          serviceUuids: uuids,
          appearance: appearance,
          flags: flags,
          txPower: txPower);
      // 名称/服务未给出品类时，用广播 Appearance(0x19) 补强（免连接即得）
      String category = id.category;
      if (category.isEmpty && id.appearance != null) {
        final ap = appearanceCategory(id.appearance);
        if (ap.isNotEmpty) category = ap;
      }
      // 无线电类型：低功耗蓝牙 / 双模蓝牙（由 Flags 判定）
      final radioType = radioTypeFromFlags(id.flags);
      // 无广播名称时，用「品牌+品类」兜底展示，避免整列“未知设备”
      final name = advName.isNotEmpty
          ? advName
          : (id.brand != '未知' && category.isNotEmpty
              ? '${id.brand} $category'
              : (id.brand != '未知' ? id.brand : '(未知设备)'));
      return Device(
        kind: DeviceKind.ble,
        id: mac,
        name: name,
        brand: id.brand,
        domestic: id.domestic,
        rssi: r.rssi,
        category: category,
        radioType: radioType,
        txPower: id.txPower,
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
