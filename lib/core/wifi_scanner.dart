import 'package:wifi_scan/wifi_scan.dart';
import '../../models/device.dart';
import 'brand_db.dart';

/// 真实 WiFi 扫描：读取周边 AP / 热点（SSID、BSSID、信号、加密）。
/// 协议字段区分：
///  - WiFi-Direct 对等端：SSID 含 DIRECT / WIFI_DIRECT → WifiType.direct
///  - 基础设施 AP：能力串含 [ESS] → WifiType.ap
///  - STA（关联终端/客户端）：普通安卓权限无法嗅探（需 monitor 监听模式），
///    数据模型已预留 WifiType.sta，待硬件/监听模式支持时直接填入即可。
class WifiScanner {
  Future<void> start() async {
    try {
      await WiFiScan.instance.startScan();
    } catch (_) {
      // 权限不足或设备受限时忽略，后续直接读取已有结果
    }
  }

  Future<List<Device>> getResults() async {
    List<WiFiAccessPoint> aps;
    try {
      aps = await WiFiScan.instance.getScannedResults();
    } catch (_) {
      return [];
    }
    final map = <String, Device>{};
    for (final ap in aps) {
      // AP 的 SSID 通常直接带品牌前缀（HUAWEI-/CMCC-/TP-LINK_/Xiaomi_ 等），优先用
      // SSID 识别；SSID 无品牌信息（如 "ZFinfo"）再回退 OUI（路由器 BSSID 为真实 MAC，
      // 未随机化，12k+ 条 OUI 库可稳定命中）。
      final ssidB = brandFromSsid(ap.ssid);
      final b = ssidB['brand'] == '未知' ? brandFromMac(ap.bssid) : ssidB;
      final id = ap.bssid.toUpperCase();
      final ssidUp = ap.ssid.toUpperCase();
      final isDirect = ssidUp.contains('DIRECT') || ssidUp.contains('WIFI_DIRECT');
      // 协议字段（capabilities）含 [ESS] 表示基础设施 AP；DIRECT 表示 WiFi-Direct 对等端。
      // 普通安卓权限下无法嗅探到 STA（关联终端），其数据模型 WifiType.sta 已预留。
      final type = isDirect ? WifiType.direct : WifiType.ap;
      map[id] = Device(
        kind: DeviceKind.wifi,
        id: id,
        name: ap.ssid.isEmpty ? '(隐藏网络)' : ap.ssid,
        brand: b['brand'] as String,
        domestic: b['domestic'] as bool,
        rssi: ap.level,
        info: ap.capabilities,
        category: '路由器',
        seized: false,
        wifiType: type,
        channel: channelFromFrequency(ap.frequency),
      );
    }
    return map.values.toList();
  }
}

/// 由 WiFi 频率换算信道号：2.4G(1-13/14)、5G(UNII)、6G。
int? channelFromFrequency(int? freq) {
  if (freq == null) return null;
  if (freq >= 2412 && freq <= 2484) {
    if (freq == 2484) return 14;
    return (freq - 2412) ~/ 5 + 1;
  }
  if (freq >= 4915 && freq <= 4980) return (freq - 4915) ~/ 5 + 183;
  if (freq >= 5035 && freq <= 5980) return (freq - 5000) ~/ 5;
  if (freq >= 5955 && freq <= 7115) return (freq - 5950) ~/ 5;
  return null;
}
