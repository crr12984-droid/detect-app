import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/ui_assets.dart';
import 'app_state.dart';
import '../features/smart/smart_page.dart';
import '../features/detection/detection_page.dart';
import '../features/positioning/positioning_page.dart';
import '../features/report/report_page.dart';
import '../features/report/preview_page.dart';
import '../features/settings/settings_page.dart';

/// 应用外壳：状态栏 + 内容区 + 底部三标签导航。
/// 通过 state.overlay / state.section 决定当前展示哪个界面。
class AppShell extends StatelessWidget {
  final AppState state;
  const AppShell({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final overlay = state.overlay;
    final showNav = overlay == null;

    Widget body;
    if (overlay == 'detection') {
      body = DetectionPage(state);
    } else if (overlay == 'position') {
      body = PositioningPage(state);
    } else if (overlay == 'preview') {
      body = PreviewPage(state);
    } else {
      switch (state.section) {
        case 1:
          body = ReportPage(state);
          break;
        case 2:
          body = SettingsPage(state);
          break;
        default:
          body = SmartPage(state);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const StatusBar(),
            Expanded(child: body),
            if (showNav) _tabBar(),
          ],
        ),
      ),
    );
  }

  Widget _tab(String icon, String label, int idx) {
    final active = state.section == idx && state.overlay == null;
    return Expanded(
      child: InkWell(
        onTap: () {
          state.section = idx;
          state.overlay = null;
          state.notify();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon,
                size: 22, color: active ? AppColors.acc : AppColors.txt3),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active ? AppColors.acc : AppColors.txt3)),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() => Container(
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: const Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          _tab('radar', '智能检测', 0),
          _tab('file-text', '报告管理', 1),
          _tab('settings', '系统设置', 2),
        ]),
      );
}

/// 顶部状态栏：实时时钟 + 音量 + 电量 + 操作员状态（与原型一致）。
class StatusBar extends StatefulWidget {
  const StatusBar({super.key});
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late String _clock;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clock = _fmt(_now);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      _now = DateTime.now();
      final c = _fmt(_now);
      if (c != _clock) setState(() => _clock = c);
      return true;
    });
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(bottom: BorderSide(color: AppColors.line, width: 0.5)),
        ),
        child: Row(
          children: [
            Text(_clock,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5)),
            const Spacer(),
            AppIcon('volume-2', size: 16, color: AppColors.txt2),
            const SizedBox(width: 14),
            Row(children: [
              AppIcon('battery-full', size: 18, color: AppColors.ok),
              const SizedBox(width: 5),
              const Text('86%',
                  style: TextStyle(fontSize: 12, color: AppColors.txt2)),
            ]),
            const SizedBox(width: 14),
            Row(children: [
              AppIcon('user', size: 15, color: AppColors.txt3),
              const SizedBox(width: 5),
              const Text('巡检员',
                  style: TextStyle(fontSize: 12, color: AppColors.txt2)),
            ]),
          ],
        ),
      );
}
