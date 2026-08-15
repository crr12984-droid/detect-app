/// 单一数据源：OUI（MAC 前 3 字节）→ 品牌与是否国产。
/// 同时服务 WiFi（BSSID）与 BLE（MAC）解析，避免多套库分叉。
const Map<String, Map<String, dynamic>> _oui = {
  // ===== 国产（domestic: true） =====
  'A491B1': {'brand': 'Huawei', 'domestic': true},
  '9C21A0': {'brand': 'Huawei', 'domestic': true},
  'C8943C': {'brand': 'Huawei', 'domestic': true},
  '9C1E07': {'brand': 'Honor', 'domestic': true},
  'AC8C5A': {'brand': 'Honor', 'domestic': true},
  '50FA84': {'brand': 'TP-Link', 'domestic': true},
  'A4C361': {'brand': 'TP-Link', 'domestic': true},
  '7C43AF': {'brand': 'Tenda', 'domestic': true},
  '14CF92': {'brand': 'Xiaomi', 'domestic': true},
  'F8A2D6': {'brand': 'Xiaomi', 'domestic': true},
  '28E1B5': {'brand': 'Xiaomi', 'domestic': true},
  '8C7DDA': {'brand': 'Xiaomi', 'domestic': true},
  '8C1DAA': {'brand': 'Xiaomi', 'domestic': true},
  '44F13A': {'brand': 'Oppo', 'domestic': true},
  '8CAAE5': {'brand': 'Oppo', 'domestic': true},
  '8CF5A3': {'brand': 'Oppo', 'domestic': true},
  'F4F135': {'brand': 'Vivo', 'domestic': true},
  'FCE34D': {'brand': 'Vivo', 'domestic': true},
  '9C7BE7': {'brand': 'Vivo', 'domestic': true},
  'B0A4B8': {'brand': 'OnePlus', 'domestic': true},
  'A45B93': {'brand': 'OnePlus', 'domestic': true},
  '7C9EBD': {'brand': 'realme', 'domestic': true},
  '64E0E0': {'brand': 'realme', 'domestic': true},
  '6CAB6E': {'brand': 'Meizu', 'domestic': true},
  '68A0F6': {'brand': 'Meizu', 'domestic': true},
  '3C91FD': {'brand': 'ZTE', 'domestic': true},
  '0C961D': {'brand': 'ZTE', 'domestic': true},
  // ===== 进口（domestic: false） =====
  'ACBC32': {'brand': 'Apple', 'domestic': false},
  'A43B1C': {'brand': 'Apple', 'domestic': false},
  'F0D59B': {'brand': 'Apple', 'domestic': false},
  '3C22FB': {'brand': 'Apple', 'domestic': false},
  '60E18B': {'brand': 'Samsung', 'domestic': false},
  '8CBCB1': {'brand': 'Samsung', 'domestic': false},
  '40F30E': {'brand': 'Samsung', 'domestic': false},
  'D85D4C': {'brand': 'Samsung', 'domestic': false},
  '2469A5': {'brand': 'Sony', 'domestic': false},
  '3C5A37': {'brand': 'Google', 'domestic': false},
  'F4CBCB': {'brand': 'Google', 'domestic': false},
  '8C882B': {'brand': 'LG', 'domestic': false},
  '189EF5': {'brand': 'Lenovo', 'domestic': true},
  '58AC78': {'brand': 'Lenovo', 'domestic': true},
};

Map<String, dynamic> brandFromMac(String mac) {
  final clean = mac.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
  if (clean.length < 6) return {'brand': '未知', 'domestic': false};
  final prefix = clean.substring(0, 6);
  return _oui[prefix] ?? {'brand': '未知', 'domestic': false};
}
