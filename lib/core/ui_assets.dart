import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme.dart';
import '../models/device.dart';

/// 品牌视觉：颜色 + 是否有 logo 资源（资源来自 _brands/，缺失则回退彩色字母徽标）。
const Map<String, Map<String, dynamic>> _brandVisual = {
  'apple': {'color': 0xFFC7D0DC, 'logo': true},
  'huawei': {'color': 0xFFFF5B5F, 'logo': true},
  'honor': {'color': 0xFFD4DCE6, 'logo': true},
  'samsung': {'color': 0xFF7BA3FF, 'logo': true},
  'xiaomi': {'color': 0xFFFF9F1C, 'logo': true},
  'tplink': {'color': 0xFF4ACBD6, 'logo': true},
  'oppo': {'color': 0xFF22C39A, 'logo': true},
  'vivo': {'color': 0xFF6D8BFF, 'logo': true},
  'oneplus': {'color': 0xFFFF5B5F, 'logo': true},
  'meizu': {'color': 0xFF4DA3FF, 'logo': true},
  'google': {'color': 0xFF4285F4, 'logo': true},
  'microsoft': {'color': 0xFF00A4EF, 'logo': true},
  'amazon': {'color': 0xFFFF9900, 'logo': true},
  'meta': {'color': 0xFF0081FB, 'logo': true},
  'lg': {'color': 0xFFA50034, 'logo': true},
  'motorola': {'color': 0xFF1A73E8, 'logo': true},
  'tenda': {'color': 0xFF00A0E9, 'logo': false},
  'realme': {'color': 0xFFFFC915, 'logo': false},
  'zte': {'color': 0xFF1D7ABF, 'logo': false},
  'sony': {'color': 0xFF9AA7B8, 'logo': false},
  'nokia': {'color': 0xFF124191, 'logo': false},
  'lenovo': {'color': 0xFFE2231A, 'logo': false},
  'tcl': {'color': 0xFFE2231A, 'logo': false},
};

/// 品类视觉：颜色 + 图标资源名（assets/icons/，缺失回退 laptop）。
const Map<String, Map<String, dynamic>> _catVisual = {
  '手机': {'color': 0xFF3B82F6, 'icon': 'smartphone'},
  '手表': {'color': 0xFF8B5CF6, 'icon': 'watch'},
  '耳机': {'color': 0xFF22B8CF, 'icon': 'headphones'},
  '平板': {'color': 0xFFF59E0B, 'icon': 'tablet'},
  '车载': {'color': 0xFF10B981, 'icon': 'car'},
  '路由器': {'color': 0xFF64748B, 'icon': 'wifi'},
};

/// 品牌 key 归一化：小写并去掉连字符等非字母数字（如 "TP-Link" → "tplink"），
/// 与 assets/brands/ 下的文件名对齐，保证真实数据匹配到的品牌能命中 logo。
String brandKey(String brand) =>
    brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

Color brandColor(String brand) {
  final v = _brandVisual[brandKey(brand)];
  return v == null ? const Color(0xFF8A97A8) : Color(v['color'] as int);
}

bool brandHasLogo(String brand) {
  final v = _brandVisual[brandKey(brand)];
  return (v?['logo'] as bool?) ?? false;
}

Color catColor(String cat) {
  final v = _catVisual[cat];
  return v == null ? const Color(0xFF64748B) : Color(v['color'] as int);
}

String catIcon(String cat) {
  final v = _catVisual[cat];
  return (v?['icon'] as String?) ?? 'device';
}

/// 品牌展示名：未知时明确标识
String brandLabel(String brand) =>
    (brand.isEmpty || brand == '未知') ? '未知品牌' : brand;

/// 品牌 logo：有 SVG 资源则渲染并染成品牌色；未知品牌用虚线"?"徽标明确标识；
/// 其余用彩色字母徽标（与原型一致）。
class BrandLogo extends StatelessWidget {
  final String brand;
  final double size;
  const BrandLogo(this.brand, {this.size = 13});
  @override
  Widget build(BuildContext context) {
    final unknown = brand.isEmpty || brand == '未知';
    final c = brandColor(brand);
    if (unknown) {
      return Container(
        width: size + 7,
        height: size + 7,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: AppColors.txt3),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text('?',
            style: TextStyle(
                color: AppColors.txt3,
                fontSize: size * 0.8,
                fontWeight: FontWeight.bold)),
      );
    }
    if (brandHasLogo(brand)) {
      return SvgPicture.asset(
        'assets/brands/${brandKey(brand)}.svg',
        width: size, height: size, color: c,
      );
    }
    return Container(
      width: size + 7, height: size + 7,
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(brand[0].toUpperCase(),
          style: TextStyle(color: c, fontSize: size * 0.8, fontWeight: FontWeight.bold)),
    );
  }
}

/// WiFi 类型标签：AP / STA / WiFi Direct
class WifiTypeTag extends StatelessWidget {
  final WifiType type;
  const WifiTypeTag(this.type);
  @override
  Widget build(BuildContext context) {
    final (label, fg) = switch (type) {
      WifiType.ap => ('AP', const Color(0xFF7FB0FF)),
      WifiType.sta => ('STA', const Color(0xFF6FD79B)),
      WifiType.direct => ('WiFi Direct', const Color(0xFFC79BFF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// 品类图标（手机/手表/耳机/平板/车载/路由器）。
/// 空品类（多为 BLE 未广播类别的设备）回退到通用「设备」图标，而非 WiFi/路由器图标。
class CatIcon extends StatelessWidget {
  final String cat;
  final double size;
  const CatIcon(this.cat, {this.size = 14});
  @override
  Widget build(BuildContext context) {
    final icon = cat.isEmpty ? 'device' : catIcon(cat);
    return SvgPicture.asset(
      'assets/icons/$icon.svg',
      width: size,
      height: size,
      color: catColor(cat),
    );
  }
}

/// 通用 UI 图标（来自 assets/icons/，如 arrow-left / settings / refresh-cw …）。
class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const AppIcon(this.name, {this.size = 20, this.color});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size, height: size, color: color ?? AppColors.txt2,
      );
}
