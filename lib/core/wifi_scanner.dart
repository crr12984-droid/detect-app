import 'package:wifi_scan/wifi_scan.dart';
import '../../models/device.dart';
import 'brand_db.dart';

/// 真实 WiFi 扫描：读取周边 AP / 热点（SSID、BSSID、信号、加密）。
/// 依据 SSID/能力区分 AP 与 WiFi Direct；STA（关联终端）在普通模式下不可见，
/// 界面与数据模型已支持 STA 类型，如硬件/监听模式可发现 STA 直接填入即可。
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
      // 优先按 OUI 识别，未命中再按 SSID 品牌关键词补充，降低「未知」比例
      final oui = brandFromMac(ap.bssid);
      final b =
          oui['brand'] == '未知' ? brandFromSsid(ap.ssid) : oui;
      final id = ap.bssid.toUpperCase();
      final ssidUp = ap.ssid.toUpperCase();
      final isDirect = ssidUp.contains('DIRECT') || ssidUp.contains('WIFI_DIRECT');
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
