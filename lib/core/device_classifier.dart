import 'company_db.dart';
import 'brand_db.dart';

/// BLE 广播数据的识别结果
class BleId {
  final String brand;
  final bool domestic;
  final String category; // 手机 / 手表 / 耳机 / 平板 / 车载 / 路由器 / ''未知
  final String? model; // 名称中带出的型号（如 "iPhone 15"、"AirPods Pro"）
  const BleId({
    required this.brand,
    required this.domestic,
    required this.category,
    this.model,
  });
}

/// 依据 BLE 广播包识别品牌、类别与型号。
/// 优先级：Company ID → 名称关键词 → Service UUID → OUI 兜底。
/// （BLE 的广播 MAC 多为随机地址，OUI 只能作为最后兜底。）
BleId classifyBle({
  required String mac,
  required String name,
  required int? companyId,
  required List<String> serviceUuids,
}) {
  final n = name.trim().toLowerCase();

  // 1) Company ID → 品牌（最可靠）
  String? brand = companyId == null ? null : brandFromCompanyId(companyId);

  // 2) 名称关键词 → 品牌（覆盖华为/小米/OPPO/vivo 等常见命名）
  brand ??= _brandFromName(n);

  // 3) 类别：名称关键词 → Service UUID
  String category = _categoryFromName(n);
  if (category.isEmpty) category = _categoryFromServices(serviceUuids);

  // 4) 型号：从名称中带出的精确机型
  final model = _modelFromName(name);

  // 5) OUI 兜底（仅当 MAC 未随机化时生效）
  if (brand == null) {
    final b = brandFromMac(mac);
    if (b['brand'] != '未知') brand = b['brand'] as String;
  }

  final finalBrand = brand ?? '未知';
  final domestic = brand != null ? isDomesticBrand(finalBrand) : false;
  return BleId(
      brand: finalBrand, domestic: domestic, category: category, model: model);
}

/// 苹果「机型标识」→ 市场名（如 iPhone15,4 → iPhone 15）。
/// 数据来源：苹果 DeviceIdentifier 对照表（部分常见机型）。
String appleMarketingName(String modelId) {
  const map = {
    'iPhone14,5': 'iPhone 13',
    'iPhone14,4': 'iPhone 13 mini',
    'iPhone14,2': 'iPhone 13 Pro',
    'iPhone14,3': 'iPhone 13 Pro Max',
    'iPhone15,4': 'iPhone 15',
    'iPhone15,5': 'iPhone 15 Plus',
    'iPhone15,2': 'iPhone 14 Pro',
    'iPhone15,3': 'iPhone 14 Pro Max',
    'iPhone16,1': 'iPhone 15 Pro',
    'iPhone16,2': 'iPhone 15 Pro Max',
    'A2031': 'AirPods (2代)',
    'A2032': 'AirPods (2代)',
    'A2083': 'AirPods Pro',
    'A2084': 'AirPods Pro',
    'A2096': 'AirPods Max',
    'A2564': 'AirPods (3代)',
    'A2565': 'AirPods (3代)',
    'A2698': 'AirPods Pro (2代)',
    'A2699': 'AirPods Pro (2代)',
    'A2700': 'AirPods Pro (2代)',
  };
  return map[modelId] ?? modelId;
}

// ---------- 名称关键词 → 品牌 ----------
String? _brandFromName(String n) {
  if (n.contains('apple') ||
      n.contains('airpods') ||
      n.contains('iphone') ||
      n.contains('ipad') ||
      n.contains('ipod') ||
      n.contains('homepod')) {
    return 'Apple';
  }
  if (n.contains('huawei')) return 'Huawei';
  if (n.contains('honor')) return 'Honor';
  if (n.startsWith('mi ') ||
      n.contains('xiaomi') ||
      n.contains('redmi') ||
      n.contains('mi band')) {
    return 'Xiaomi';
  }
  if (n.contains('samsung') || n.contains('galaxy')) return 'Samsung';
  if (n.contains('oppo')) return 'OPPO';
  if (n.contains('vivo')) return 'vivo';
  if (n.contains('oneplus') || n.contains('一加')) return 'OnePlus';
  if (n.contains('realme')) return 'realme';
  if (n.contains('meizu')) return 'Meizu';
  if (n.contains('zte')) return 'ZTE';
  if (n.contains('sony')) return 'Sony';
  if (n.contains('google') || n.contains('pixel')) return 'Google';
  if (n.contains('nokia')) return 'Nokia';
  if (n.contains('tcl')) return 'TCL';
  return null;
}

// ---------- 名称关键词 → 类别 ----------
String _categoryFromName(String n) {
  if (n.contains('airpods') ||
      n.contains('buds') ||
      n.contains('earbud') ||
      n.contains('headphone') ||
      n.contains('freebuds') ||
      n.contains('enco') ||
      n.contains('耳机')) {
    return '耳机';
  }
  if (n.contains('watch') ||
      n.contains('band') ||
      n.contains('手环') ||
      n.contains('手表')) {
    return '手表';
  }
  if (n.contains('pad') ||
      n.contains('tab') ||
      n.contains('tablet') ||
      n.contains('平板')) {
    return '平板';
  }
  if (n.contains('mouse') || n.contains('鼠标')) return '鼠标';
  if (n.contains('keyboard') || n.contains('键盘')) return '键盘';
  if (n.contains('speaker') ||
      n.contains('音箱') ||
      n.contains('音响') ||
      n.contains('soundbar')) {
    return '音箱';
  }
  if (n.contains('tv') || n.contains('电视') || n.contains('smarttv')) {
    return '电视';
  }
  if (n.contains('laptop') ||
      n.contains('笔记本') ||
      n.contains('电脑') ||
      n.contains('macbook') ||
      n.contains(' pc') ||
      n.contains('pc ')) {
    return '笔电';
  }
  if (n.contains('iphone') ||
      n.contains('phone') ||
      n.contains('手机') ||
      n.contains('galaxy') ||
      n.contains('redmi') ||
      n.contains('pixel') ||
      n.contains('mate') ||
      n.contains('p40') ||
      n.contains('p50') ||
      n.startsWith('mi ')) {
    return '手机';
  }
  if (n.contains('car') || n.contains('车载')) return '车载';
  if (n.contains('router') || n.contains('路由')) return '路由器';
  return '';
}

// ---------- 名称中带出的型号 ----------
String? _modelFromName(String name) {
  final n = name.trim();
  final iphone = RegExp(r'iphone\s*\d{1,2}(\s*(pro|max|plus|mini))?',
          caseSensitive: false)
      .firstMatch(n);
  if (iphone != null) return iphone.group(0)!;
  final airpods = RegExp(r'airpods\s*(pro|max|\d+)?', caseSensitive: false)
      .firstMatch(n);
  if (airpods != null) return airpods.group(0)!;
  final galaxy = RegExp(r'galaxy\s*[sz]\d+', caseSensitive: false)
      .firstMatch(n);
  if (galaxy != null) return galaxy.group(0)!;
  return null;
}

// ---------- Service UUID → 类别 ----------
/// BLE 广播的 Service UUID 是识别品类的可靠补充（尤其当设备未广播名称时）。
/// 优先级：音频类→耳机，HID(键鼠)→鼠标，心率/运动健康→手表，生态 beacon→手机。
/// 注意 HID(1810/1812/1813) 与部分健康 UUID 同处 181x 段，必须放在健康段之前判断。
String _categoryFromServices(List<String> uuids) {
  final set = uuids.map((u) => u.toLowerCase().replaceAll('-', '')).toSet();
  bool has(String p) => set.any((u) => u.contains(p));
  // 经典/低功耗音频
  const audio = {
    '1108', '110a', '110b', '111e',
    '184b', '184c', '184d', '184e', '184f',
    '1850', '1851', '1852', '1853', '1854', '1855', '1856', '1857', '1858', '1859',
    '185a', '185b', '185c', '185d', '185e', '185f',
  };
  // HID（键盘/鼠标等外设）
  const hid = {'1810', '1812', '1813'};
  // 心率 / 运动健康 / 体重等穿戴
  const health = {
    '180d', '1814', '1816', '1808', '1809', '181c', '181d', '1821', '1822',
    '1811', '1815', '1817', '1818', '1819', '181a', '181b', '181f', '1820',
    '1823', '1824', '1825', '1826', '1827', '1828', '1829', '182a', '182b',
    '182c', '182d', '182e', '182f', '1830',
  };
  if (audio.any(has)) return '耳机';
  if (hid.any(has)) return '鼠标';
  if (health.any(has)) return '手表';
  if (has('fd6f')) return '手机'; // Apple Continuity
  if (has('fe95')) return '手机'; // 小米生态
  if (has('feaa')) return '手机'; // Google Eddystone
  return '';
}
