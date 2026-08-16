import 'package:wifi_scan/wifi_scan.dart';
import '../../models/device.dart';
import 'brand_db.dart';

/// 演示用：为每个 AP 生成若干"关联终端(STA)"以展示拓扑。
/// 说明：普通 Android 在非 AP/监听模式下无法直接发现其它 STA 的 MAC，
/// 此处按产品需求做拓扑可视化演示；当硬件/权限支持真实 STA 发现时，
/// 将真实数据填入 Device.linkedSta 即可，无需改动 UI。
const bool kDemoTopology = true;

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
      final ssidUp = ap.ssid.toUpperCase();
      final isDirect = ssidUp.contains('DIRECT') || ssidUp.contains('WIFI_DIRECT');
      final type = isDirect ? WifiType.direct : WifiType.ap;
      final linked = <StaLink>[];
      if (kDemoTopology && !isDirect) {
        // 演示拓扑：生成 1~2 个关联 STA
        final n = 1 + (id.hashCode % 2);
        for (var i = 0; i < n; i++) {
          linked.add(StaLink(
            mac: _fakeMac(id, i),
            brand: _demoBrand(i),
            rssi: (ap.level - 6 - i * 4).clamp(-95, -30),
          ));
        }
      }
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
        linkedSta: linked,
      );
    }
    return map.values.toList();
  }

  String _fakeMac(String base, int i) {
    final tail = (base.hashCode + i * 7919).toRadixString(16).toUpperCase().padLeft(12, '0');
    return '${base.substring(0, 8)}${tail.substring(8, 12)}';
  }

  String _demoBrand(int i) {
    const demo = ['Apple', 'Xiaomi', 'Samsung', 'Huawei', 'OPPO'];
    return demo[(i + 1) % demo.length];
  }
}
