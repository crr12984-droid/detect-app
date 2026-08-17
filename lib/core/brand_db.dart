import 'oui_map.dart';

/// 单一数据源：OUI（MAC 前 3 字节）→ 品牌与是否国产。
/// kOuiToBrand 由 gen_oui.py 从 IEEE OUI 权威库生成（覆盖华为/苹果/三星/TP-Link/小米等
/// 上万个 OUI），_ouiExtra 补充少量 IEEE 库未收录的手机厂商 OUI，二者合并以最大化命中率、
/// 降低「未知」比例。同时服务 WiFi（BSSID）与 BLE（MAC）解析，避免多套库分叉。
const Map<String, String> _ouiExtra = {
  'A491B1': 'Huawei',
  '9C21A0': 'Huawei',
  'C8943C': 'Huawei',
  '9C1E07': 'Honor',
  'AC8C5A': 'Honor',
  '50FA84': 'TP-Link',
  'A4C361': 'TP-Link',
  '7C43AF': 'Tenda',
  '14CF92': 'Xiaomi',
  'F8A2D6': 'Xiaomi',
  '28E1B5': 'Xiaomi',
  '8C7DDA': 'Xiaomi',
  '8C1DAA': 'Xiaomi',
  '44F13A': 'OPPO',
  '8CAAE5': 'OPPO',
  '8CF5A3': 'OPPO',
  'F4F135': 'vivo',
  'FCE34D': 'vivo',
  '9C7BE7': 'vivo',
  'B0A4B8': 'OnePlus',
  'A45B93': 'OnePlus',
  '7C9EBD': 'realme',
  '64E0E0': 'realme',
  '6CAB6E': 'Meizu',
  '68A0F6': 'Meizu',
  '3C91FD': 'ZTE',
  '0C961D': 'ZTE',
  'ACBC32': 'Apple',
  'A43B1C': 'Apple',
  'F0D59B': 'Apple',
  '3C22FB': 'Apple',
  '60E18B': 'Samsung',
  '8CBCB1': 'Samsung',
  '40F30E': 'Samsung',
  'D85D4C': 'Samsung',
  '2469A5': 'Sony',
  '3C5A37': 'Google',
  'F4CBCB': 'Google',
  '8C882B': 'LG',
  '189EF5': 'Lenovo',
  '58AC78': 'Lenovo',
};

Map<String, dynamic> brandFromMac(String mac) {
  final clean = mac.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
  if (clean.length < 6) return {'brand': '未知', 'domestic': false};
  final prefix = clean.substring(0, 6);
  final brand = kOuiToBrand[prefix] ?? _ouiExtra[prefix];
  if (brand == null) return {'brand': '未知', 'domestic': false};
  return {'brand': brand, 'domestic': kOuiDomestic.contains(brand)};
}

/// SSID 关键词 → 品牌（OUI 未命中时的补充识别，AP 场景尤其可靠）。
/// 许多路由/热点出厂 SSID 即带品牌前缀（如 HUAWEI-XXX、Xiaomi_Guest、CMCC-XXXX、
/// DIRECT-xx、iPhone），可据此降低「未知」比例。品牌串与 kOuiToBrand / kOuiDomestic 保持一致。
const Map<String, String> _ssidBrand = {
  // 华为 / 荣耀
  'HUAWEI': 'Huawei',
  'HONOR': 'Honor',
  'HILINK': 'Huawei',
  'WS831': 'Huawei',
  'WS832': 'Huawei',
  'WS850': 'Huawei',
  'WS650': 'Huawei',
  // 小米 / 红米
  'XIAOMI': 'Xiaomi',
  'REDMI': 'Xiaomi',
  'MIWIFI': 'Xiaomi',
  'MI-': 'Xiaomi',
  'MI_': 'Xiaomi',
  // OPPO / vivo / realme / 一加 / 魅族
  'OPPO': 'OPPO',
  'VIVO': 'vivo',
  'REALME': 'realme',
  'ONEPLUS': 'OnePlus',
  'MEIZU': 'Meizu',
  // 中兴
  'ZTE': 'ZTE',
  // 运营商（光猫 / 路由）
  'CMCC': 'ChinaMobile',
  'CHINAMOBILE': 'ChinaMobile',
  'CHINANET': 'ChinaTelecom',
  'CHINATELECOM': 'ChinaTelecom',
  'CHINAUNICOM': 'ChinaUnicom',
  'UNICOM': 'ChinaUnicom',
  // TP-Link 系
  'TP-LINK': 'TP-Link',
  'TPLINK': 'TP-Link',
  'MERCUSYS': 'Mercusys',
  // 其它路由
  'TENDA': 'Tenda',
  'MERCURY': 'Mercury',
  'FAST': 'Fast',
  'NETGEAR': 'Netgear',
  'ASUS': 'ASUS',
  'RT-': 'ASUS',
  'D-LINK': 'D-Link',
  'DIR': 'D-Link',
  'ARUBA': 'Aruba',
  'CISCO': 'Cisco',
  'LINKSYS': 'Linksys',
  'UBNT': 'Ubiquiti',
  'UBIQUITI': 'Ubiquiti',
  'MIKROTIK': 'MikroTik',
  // 企业网（国产）
  'H3C': 'H3C',
  'RUIJIE': 'Ruijie',
  'RG-': 'Ruijie',
  'FIBERHOME': 'Fiberhome',
  'FH-': 'Fiberhome',
  'PHICOMM': 'Phicomm',
  'JF': 'Phicomm',
  'JCG': 'JCG',
  'TOTOLINK': 'TOTOLINK',
  'EDIMAX': 'EDIMAX',
  'TRENDNET': 'TRENDnet',
  // 家电
  'HISENSE': 'Hisense',
  'TCL': 'TCL',
  'HAIER': 'Haier',
  'GREE': 'Gree',
  'SKYWORTH': 'Skyworth',
  'KONKA': 'Konka',
  // 互联网盒子
  'XIAODU': 'Baidu',
  'BAIDU': 'Baidu',
  'YOUKU': 'Youku',
  // 手机热点
  'IPHONE': 'Apple',
  'IPAD': 'Apple',
  'APPLE': 'Apple',
  'AIRPORT': 'Apple',
  'SAMSUNG': 'Samsung',
  'GALAXY': 'Samsung',
  'GOOGLE': 'Google',
  'NEST': 'Google',
  'PIXEL': 'Google',
  'LG': 'LG',
  'SONY': 'Sony',
  'MOTO': 'Motorola',
};

/// SSID 品牌识别：返回 {'brand','domestic'}。命中返回品牌，未命中返回未知。
Map<String, dynamic> brandFromSsid(String ssid) {
  final s = ssid.toUpperCase();
  String? brand;
  for (final k in _ssidBrand.keys) {
    if (s.contains(k)) {
      brand = _ssidBrand[k];
      break;
    }
  }
  if (brand == null) return {'brand': '未知', 'domestic': false};
  return {'brand': brand, 'domestic': kOuiDomestic.contains(brand)};
}
