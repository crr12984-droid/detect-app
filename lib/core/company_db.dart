/// Bluetooth SIG 分配的公司标识符（16-bit Company ID）→ 品牌。
/// 数据来源：Bluetooth SIG Assigned Numbers
/// https://www.bluetooth.com/specifications/assigned-numbers/company-identifiers/
/// 说明：BLE 广播的「Manufacturer Specific Data」前两字节即为公司 ID，
/// 这是识别设备品牌的**最可靠**来源（不依赖随机化的 MAC）。
const Map<int, String> kCompanyToBrand = {
  0x0001: 'Nokia',
  0x0002: 'Intel',
  0x0006: 'Microsoft',
  0x0008: 'Motorola',
  0x000A: 'Qualcomm',
  0x000F: 'Broadcom',
  0x001D: 'Qualcomm',
  0x0046: 'MediaTek',
  0x004C: 'Apple',
  0x0056: 'Sony',
  0x0059: 'Nordic',
  0x005D: 'Realtek',
  0x0075: 'Samsung',
  0x0078: 'Nike',
  0x0087: 'Garmin',
  0x0095: 'Huawei',
  0x00C4: 'LG',
  0x00E0: 'Google',
  0x012D: 'Sony',
  0x0157: 'Xiaomi',
  0x0171: 'Amazon',
  0x018E: 'Google',
  0x01AB: 'Meta',
  0x027D: 'Huawei',
  0x02E5: 'Espressif',
  0x038F: 'Xiaomi',
  0x040F: 'OnePlus',
  0x067C: 'Tile',
};

String? brandFromCompanyId(int id) => kCompanyToBrand[id];

/// 国产品牌集合（用于「国产/进口」标签）
const Set<String> kDomesticBrands = {
  'Huawei', 'Honor', 'Xiaomi', 'OPPO', 'vivo', 'OnePlus', 'realme', 'Meizu',
  'ZTE', 'TP-Link', 'Tenda', 'Lenovo',
};

bool isDomesticBrand(String brand) => kDomesticBrands.contains(brand);
