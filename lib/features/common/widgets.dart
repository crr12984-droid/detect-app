import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/distance.dart';
import '../../models/device.dart';

/// 区块标题（蓝点 + 标题），对应原型 .sec-head
class SecHead extends StatelessWidget {
  final String title;
  const SecHead(this.title);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 6, height: 18, decoration: BoxDecoration(color: AppColors.acc, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ]);
}

/// 4 格信号条（检测列表行内）
class SignalBars4 extends StatelessWidget {
  final int rssi;
  const SignalBars4(this.rssi);
  @override
  Widget build(BuildContext context) {
    final n = rssiToBars4(rssi);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final h = 5 + i * 3;
        return Container(
          width: 3,
          height: h.toDouble(),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: i < n ? AppColors.acc2 : const Color(0xFF33404F),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

/// 8 格信号条（定位信号卡）
class SignalBars8 extends StatelessWidget {
  final int rssi;
  final double size;
  const SignalBars8(this.rssi, {this.size = 22});
  @override
  Widget build(BuildContext context) {
    final n = rssiToBars(rssi).clamp(0, 8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(8, (i) {
        return Container(
          width: size / 8 * 0.6,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: i < n ? const Color(0xFFFACC15) : Colors.transparent,
            border: Border.all(color: const Color(0xFF46536A)),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class ZoneTag extends StatelessWidget {
  final bool indoor;
  const ZoneTag(this.indoor);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: indoor
              ? AppColors.acc.withOpacity(0.13)
              : AppColors.ok.withOpacity(0.13),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(indoor ? '室内' : '室外',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: indoor
                    ? const Color(0xFF8FB6FF)
                    : const Color(0xFF5FCA86))),
      );
}

class DomesticTag extends StatelessWidget {
  final bool domestic;
  const DomesticTag(this.domestic);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: domestic
              ? AppColors.ok.withOpacity(0.15)
              : AppColors.warn.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(domestic ? '国产' : '进口',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: domestic
                    ? const Color(0xFF4CC079)
                    : const Color(0xFFE0B463))),
      );
}

class RadioTypeTag extends StatelessWidget {
  final RadioType radioType;
  const RadioTypeTag(this.radioType);
  @override
  Widget build(BuildContext context) {
    final isLe = radioType == RadioType.lowEnergy;
    final color = isLe ? AppColors.acc : AppColors.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(radioTypeLabel(radioType),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
  ));
}
