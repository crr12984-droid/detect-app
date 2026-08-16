import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme.dart';

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
  'tenda': {'color': 0xFF8A97A8, 'logo': false},
  'realme': {'color': 0xFFFFC915, 'logo': false},
  'zte': {'color': 0xFF9AA7B8, 'logo': false},
  'sony': {'color': 0xFF9AA7B8, 'logo': false},
  'google': {'color': 0xFF9AA7B8, 'logo': false},
  'lg': {'color': 0xFF9AA7B8, 'logo': false},
  'lenovo': {'color': 0xFF9AA7B8, 'logo': false},
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

Color brandColor(String brand) {
  final v = _brandVisual[brand.toLowerCase()];
  return v == null ? const Color(0xFF8A97A8) : Color(v['color'] as int);
}

bool brandHasLogo(String brand) {
  final v = _brandVisual[brand.toLowerCase()];
  return (v?['logo'] as bool?) ?? false;
}

Color catColor(String cat) {
  final v = _catVisual[cat];
  return v == null ? const Color(0xFF64748B) : Color(v['color'] as int);
}

String catIcon(String cat) {
  final v = _catVisual[cat];
  return (v?['icon'] as String?) ?? 'laptop';
}

/// 品牌 logo：有 SVG 资源则渲染并染成品牌色，否则彩色字母徽标（与原型一致）。
class BrandLogo extends StatelessWidget {
  final String brand;
  final double size;
  const BrandLogo(this.brand, {this.size = 13});
  @override
  Widget build(BuildContext context) {
    final c = brandColor(brand);
    if (brandHasLogo(brand)) {
      return SvgPicture.asset(
        'assets/brands/${brand.toLowerCase()}.svg',
        width: size, height: size, color: c,
      );
    }
    return Container(
      width: size + 7, height: size + 7,
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(brand.isNotEmpty ? brand[0].toUpperCase() : '?',
          style: TextStyle(color: c, fontSize: size * 0.8, fontWeight: FontWeight.bold)),
    );
  }
}

/// 品类图标（手机/手表/耳机/平板/车载/路由器）。
class CatIcon extends StatelessWidget {
  final String cat;
  final double size;
  const CatIcon(this.cat, {this.size = 14});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/${catIcon(cat)}.svg',
        width: size, height: size, color: catColor(cat),
      );
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
