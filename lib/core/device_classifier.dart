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
  if (n.contains('redmi') || n.contains('xiaomi') || n.contains('mi band')) {
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
  if (n.contains('iphone') ||
      n.contains('phone') ||
      n.contains('手机') ||
      n.contains('galaxy') ||
      n.contains('redmi') ||
      n.contains('pixel') ||
      n.contains('mate') ||
      n.contains('p40') ||
      n.contains('p50')) {
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
String _categoryFromServices(List<String> uuids) {
  final set = uuids.map((u) => u.toLowerCase().replaceAll('-', '')).toSet();
  if (set.any((u) => u.contains('fd6f'))) return '手机'; // Apple Continuity
  if (set.any((u) => u.contains('180d'))) return '手表'; // Heart Rate
  if (set.any((u) => u.contains('fe95'))) return '手机'; // 小米生态
  if (set.any((u) => u.contains('feaa'))) return '手机'; // Google Eddystone
  return '';
}
