import 'package:flutter/material.dart';
import '../../app/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui_assets.dart';
import '../../core/distance.dart';
import '../common/widgets.dart';

/// 系统设置页：告警阈值 / 室内距离阈值 / 哨兵模式 / 声音告警 / 时间设置 / 版本 / 品牌库。
class SettingsPage extends StatelessWidget {
  final AppState state;
  const SettingsPage(this.state);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecHead('系统设置'),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(children: [
              _inlineSlider(
                icon: 'zap',
                label: '告警阈值',
                hint: '预计 ${rssiToDistance(state.thresholdDbm).toStringAsFixed(1)} 米',
                value: state.thresholdDbm.toDouble(),
                min: -100,
                max: 0,
                step: 1,
                unit: 'dBm',
                onChanged: (v) {
                  state.thresholdDbm = v.round();
                  state.notify();
                },
              ),
              _divider(),
              _inlineSlider(
                icon: 'radar',
                label: '室内判定阈值（信号强度）',
                hint: '预计 ${rssiToDistance(state.indoorThr).toStringAsFixed(1)} 米',
                value: state.indoorThr.toDouble(),
                min: -100,
                max: 0,
                step: 1,
                unit: 'dBm',
                onChanged: (v) {
                  state.indoorThr = v.round();
                  state.notify();
                },
              ),
              _divider(),
              _rowSwitch(
                icon: 'shield-check',
                label: '哨兵模式',
                value: state.sentinel,
                onChanged: (v) {
                  state.sentinel = v;
                  state.notify();
                },
              ),
              _divider(),
              _rowSwitch(
                icon: 'bell',
                label: '声音告警',
                value: state.sound,
                onChanged: (v) {
                  state.sound = v;
                  state.notify();
                },
              ),
              _divider(),
              _rowButton(
                icon: 'clock',
                label: '时间设置',
                hint: state.devTime.isEmpty ? '系统时间' : state.devTime,
                onTap: () => _setTime(context),
              ),
              _divider(),
              _rowButton(
                icon: 'info',
                label: '版本号',
                hint: 'v1.0.0',
                trailing: _miniBtn(context, '检查更新', () {
                  toast(context, '已是最新版本 v1.0.0');
                }),
              ),
              _divider(),
              _rowButton(
                icon: 'shield-check',
                label: '品牌库更新',
                trailing: _miniBtn(context, '检查更新', () {
                  toast(context, '品牌库已是最新');
                }),
              ),
            ]),
          ),
        ]),
      );

  Widget _inlineSlider(
      {required String icon,
      required String label,
      required String hint,
      required double value,
      required double min,
      required double max,
      required double step,
      required String unit,
      required ValueChanged<double> onChanged}) {
    final isInt = step == 1;
    final valTxt = isInt ? value.toInt().toString() : value.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppIcon(icon, size: 18, color: AppColors.txt2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(hint,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.txt3)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$valTxt $unit',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.acc2)),
          ),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: AppColors.acc,
            inactiveTrackColor: AppColors.line,
            thumbColor: AppColors.acc,
            overlayColor: AppColors.acc.withOpacity(0.15),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / step).round(),
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }

  Widget _rowSwitch(
      {required String icon,
      required String label,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(children: [
        AppIcon(icon, size: 18, color: AppColors.txt2),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
        _Switch(value: value, onChanged: onChanged),
      ]),
    );
  }

  Widget _rowButton(
      {required String icon,
      required String label,
      String? hint,
      Widget? trailing,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(children: [
          AppIcon(icon, size: 18, color: AppColors.txt2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 13.5)),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(hint,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.txt3)),
              ],
            ]),
          ),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }

  Widget _miniBtn(BuildContext ctx, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.acc,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _divider() => const Divider(height: 1, color: AppColors.line, indent: 14, endIndent: 14);

  Future<void> _setTime(BuildContext ctx) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: ctx,
      initialTime: state.devTime.isEmpty
          ? now
          : TimeOfDay(
              hour: int.tryParse(state.devTime.split(':')[0]) ?? now.hour,
              minute: int.tryParse(state.devTime.split(':')[1]) ?? now.minute,
            ),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.acc),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      state.devTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      state.notify();
      toast(ctx, '时间已设为 ${state.devTime}');
    }
  }
}

/// 与原型一致的开关（轨道 + 滑块）
class _Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 46,
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: value ? AppColors.acc : AppColors.panel2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      );
}
