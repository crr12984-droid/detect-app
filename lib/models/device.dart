import '../core/distance.dart';

enum DeviceKind { wifi, ble }

/// WiFi 设备类型（用于 AP / STA / WiFi Direct 区分与拓扑展示）
enum WifiType { ap, sta, direct }

/// 蓝牙无线电类型（由广播 Flags 判定：低功耗 / 经典 / 双模）
enum RadioType { lowEnergy, classic, dual }

/// 无线电类型显示名
String radioTypeLabel(RadioType t) {
  switch (t) {
    case RadioType.lowEnergy:
      return '低功耗蓝牙';
    case RadioType.classic:
      return '经典蓝牙';
    case RadioType.dual:
      return '双模蓝牙';
  }
}

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
  final RadioType radioType; // 蓝牙类型：低功耗蓝牙 / 经典蓝牙 / 双模蓝牙
  bool seized; // 是否被查扣
  final String? model; // 精确型号（名称带出或连接后读 DIS 获得）
  final int? txPower; // 广播 Tx Power Level(dBm)，用于路径损耗测距
  final String? serial; // GATT 设备信息服务 0x2A25 序列号（设备唯一指纹/去重）
  final WifiType? wifiType; // 仅 WiFi：AP / STA / Direct
  final int? channel; // 仅 WiFi：信道（由频率换算）
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
    this.radioType = RadioType.lowEnergy,
    this.seized = false,
    this.model,
    this.txPower,
    this.serial,
    this.wifiType,
    this.channel,
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
          String? model,
          String? brand,
          bool? domestic,
          String? category,
          RadioType? radioType,
          int? txPower,
          String? serial,
          WifiType? wifiType,
          int? channel,
          List<StaLink>? linkedSta}) =>
      Device(
        kind: kind,
        id: id,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        domestic: domestic ?? this.domestic,
        rssi: rssi ?? this.rssi,
        info: info,
        category: category ?? this.category,
        radioType: radioType ?? this.radioType,
        seized: seized ?? this.seized,
        model: model ?? this.model,
        txPower: txPower ?? this.txPower,
        serial: serial ?? this.serial,
        wifiType: wifiType ?? this.wifiType,
        channel: channel ?? this.channel,
        linkedSta: linkedSta ?? this.linkedSta,
        firstSeen: firstSeen,
        lastSeen: DateTime.now(),
        seen: seen ?? this.seen,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'id': id,
        'name': name,
        'brand': brand,
        'domestic': domestic,
        'rssi': rssi,
        'info': info,
        'category': category,
        'radioType': radioType.name,
        'seized': seized,
        'model': model,
        'txPower': txPower,
        'serial': serial,
        'wifiType': wifiType?.name,
        'channel': channel,
        'linkedSta': linkedSta
            .map((s) => {'mac': s.mac, 'brand': s.brand, 'rssi': s.rssi})
            .toList(),
        'firstSeen': firstSeen.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
        'seen': seen,
      };

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        kind: DeviceKind.values.byName(j['kind'] as String),
        id: j['id'] as String,
        name: j['name'] as String,
        brand: j['brand'] as String,
        domestic: j['domestic'] as bool,
        rssi: j['rssi'] as int,
        info: j['info'] as String?,
        category: (j['category'] as String?) ?? '',
        radioType: RadioType.values
            .byName((j['radioType'] as String?) ?? 'lowEnergy'),
        seized: (j['seized'] as bool?) ?? false,
        model: j['model'] as String?,
        txPower: j['txPower'] as int?,
        serial: j['serial'] as String?,
        wifiType: j['wifiType'] == null
            ? null
            : WifiType.values.byName(j['wifiType'] as String),
        channel: j['channel'] as int?,
        linkedSta: (j['linkedSta'] as List?)
                ?.map((e) => StaLink(
                      mac: (e as Map)['mac'] as String,
                      brand: (e)['brand'] as String,
                      rssi: (e)['rssi'] as int,
                    ))
                .toList() ??
            const [],
        firstSeen: DateTime.parse(j['firstSeen'] as String),
        lastSeen: DateTime.parse(j['lastSeen'] as String),
        seen: (j['seen'] as int?) ?? 1,
      );
}

/// 未知品牌的统一标识
const String kUnknownBrand = '未知';
