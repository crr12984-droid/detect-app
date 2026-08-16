import 'package:wifi_scan/wifi_scan.dart';
import '../../models/device.dart';
import 'brand_db.dart';

/// 真实 WiFi 扫描：读取周边 AP / 热点（SSID、BSSID、信号、加密）。
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
      final b = brandFromMac(ap.bssid);
      final id = ap.bssid.toUpperCase();
      map[id] = Device(
        kind: DeviceKind.wifi,
        id: id,
        name: ap.ssid.isEmpty ? '(隐藏网络)' : ap.ssid,
        brand: b['brand'] as String,
        domestic: b['domestic'] as bool,
        rssi: ap.level,
        info: ap.capabilities,
      );
    }
    return map.values.toList();
  }
}
