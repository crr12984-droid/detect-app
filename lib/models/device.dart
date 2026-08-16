import '../core/distance.dart';

enum DeviceKind { wifi, ble }

/// WiFi 设备类型（用于 AP / STA / WiFi Direct 区分与拓扑展示）
enum WifiType { ap, sta, direct }

/// AP 下挂的关联终端（拓扑展示用）
class StaLink {
  final String mac;
  final String brand;
  final int rssi;
  StaLink({required this.mac, required this.brand, required this.rssi});
}

/// 一台被真实扫描到的设备（WiFi AP 或 BLE 周边设备）
class Device {
  final DeviceKind kind;
  final String id; // BSSID / MAC，大写、无分隔符
  final String name; // SSID 或蓝牙设备名
  final String brand; // 由 OUI 解析出的品牌
  final bool domestic; // 是否国产
  final int rssi; // 实时信号强度 dBm（真实）
  final String? info; // WiFi: 加密方式；BLE: 可选
  final String category; // 路由器 / 手机 / 手表 / 耳机 / 平板 / 车载 / ''未知
  bool seized; // 是否被查扣
  final WifiType? wifiType; // 仅 WiFi：AP / STA / Direct
  final List<StaLink> linkedSta; // 仅 WiFi AP：下挂关联终端
  final DateTime firstSeen;
  DateTime lastSeen;
  int seen;

  Device({
    required this.kind,
    required this.id,
    required this.name,
    required this.brand,
    required this.domestic,
    required this.rssi,
    this.info,
    this.category = '',
    this.seized = false,
    this.wifiType,
    this.linkedSta = const [],
    DateTime? firstSeen,
    DateTime? lastSeen,
    this.seen = 1,
  })  : firstSeen = firstSeen ?? DateTime.now(),
        lastSeen = lastSeen ?? DateTime.now();

  /// 由实时 RSSI 估算的距离（米）
  double get distance => rssiToDistance(rssi);

  /// 8 格信号强度（用于定位信号卡 / 定位器）
  int get bars => rssiToBars(rssi);

  Device copyWith(
          {int? rssi,
          int? seen,
          bool? seized,
          String? name,
          WifiType? wifiType,
          List<StaLink>? linkedSta}) =>
      Device(
        kind: kind,
        id: id,
        name: name ?? this.name,
        brand: brand,
        domestic: domestic,
        rssi: rssi ?? this.rssi,
        info: info,
        category: category,
        seized: seized ?? this.seized,
        wifiType: wifiType ?? this.wifiType,
        linkedSta: linkedSta ?? this.linkedSta,
        firstSeen: firstSeen,
        lastSeen: DateTime.now(),
        seen: seen ?? this.seen,
      );
}

/// 未知品牌的统一标识
const String kUnknownBrand = '未知';
