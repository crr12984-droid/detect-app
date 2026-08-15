import '../core/distance.dart';

enum DeviceKind { wifi, ble }

/// 一台被真实扫描到的设备（WiFi AP 或 BLE 周边设备）
class Device {
  final DeviceKind kind;
  final String id;        // BSSID / MAC，大写、无分隔符
  final String name;      // SSID 或蓝牙设备名
  final String brand;     // 由 OUI 解析出的品牌
  final bool domestic;    // 是否国产
  final int rssi;         // 实时信号强度 dBm（真实）
  final String? info;     // WiFi: 加密方式；BLE: 可选
  final DateTime firstSeen;
  final DateTime lastSeen;
  int seen;

  Device({
    required this.kind,
    required this.id,
    required this.name,
    required this.brand,
    required this.domestic,
    required this.rssi,
    this.info,
    DateTime? firstSeen,
    DateTime? lastSeen,
    this.seen = 1,
  })  : firstSeen = firstSeen ?? DateTime.now(),
        lastSeen = lastSeen ?? DateTime.now();

  /// 由实时 RSSI 估算的距离（米），经验模型
  double get distance => rssiToDistance(rssi);

  /// 8 格信号强度指示（0~8）
  int get bars => rssiToBars(rssi);

  Device copyWith({int? rssi, int? seen}) => Device(
        kind: kind,
        id: id,
        name: name,
        brand: brand,
        domestic: domestic,
        rssi: rssi ?? this.rssi,
        info: info,
        firstSeen: firstSeen,
        lastSeen: DateTime.now(),
        seen: seen ?? this.seen,
      );
}
