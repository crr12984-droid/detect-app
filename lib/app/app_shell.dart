import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
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
        child: Stack(children: [
          Column(children: [
            StatusBar(state: state),
            Expanded(child: body),
            if (showNav) _tabBar(),
          ]),
          // 导出提示：屏幕上半部居中的一小块
          if (state.bannerMsg != null)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.16,
              left: 0,
              right: 0,
              child: Center(child: _banner(state.bannerMsg!)),
            ),
        ]),
      ),
    );
  }

  Widget _banner(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xF01F8A4C),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6))
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(msg,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
        ]),
      );

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

/// 顶部状态栏：实时时钟 + 音量(点击图标下方弹出小控制条) + 真实电量 + 操作员。
class StatusBar extends StatefulWidget {
  final AppState state;
  const StatusBar({super.key, required this.state});
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late String _clock;
  int _batt = 0;
  OverlayEntry? _volEntry;

  @override
  void initState() {
    super.initState();
    _clock = _fmt(DateTime.now());
    _readBattery();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      final c = _fmt(DateTime.now());
      if (c != _clock) setState(() => _clock = c);
      return true;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return false;
      _readBattery();
      return true;
    });
  }

  Future<void> _readBattery() async {
    try {
      final lvl = await Battery().batteryLevel;
      if (mounted) setState(() => _batt = lvl);
    } catch (_) {}
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Color _battColor() =>
      _batt < 25 ? AppColors.bad : (_batt < 50 ? AppColors.warn : AppColors.ok);

  void _toggleVolume() {
    if (_volEntry != null) {
      _closeVolume();
      return;
    }
    final entry = OverlayEntry(builder: (_) => _buildVolOverlay());
    _volEntry = entry;
    Overlay.of(context).insert(entry);
  }

  void _closeVolume() {
    _volEntry?.remove();
    _volEntry = null;
  }

  Widget _buildVolOverlay() => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeVolume,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 42,
          right: 14,
          child: _VolumePopover(state: widget.state, onClose: _closeVolume),
        ),
      ]);

  @override
  void dispose() {
    _volEntry?.remove();
    _volEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Container(
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
          InkWell(
            onTap: _toggleVolume,
            borderRadius: BorderRadius.circular(8),
            child: Row(children: [
              AppIcon('volume-2', size: 16, color: AppColors.txt2),
              const SizedBox(width: 5),
              Text('音量 ${s.volume}',
                  style: const TextStyle(fontSize: 12, color: AppColors.txt2)),
            ]),
          ),
          const SizedBox(width: 14),
          Row(children: [
            AppIcon('battery-full', size: 18, color: _battColor()),
            const SizedBox(width: 5),
            Text('$_batt%', style: const TextStyle(fontSize: 12, color: AppColors.txt2)),
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
}

/// 音量下拉小控制条（图标下方，点击空白消失）
class _VolumePopover extends StatefulWidget {
  final AppState state;
  final VoidCallback onClose;
  const _VolumePopover({required this.state, required this.onClose});
  @override
  State<_VolumePopover> createState() => _VolumePopoverState();
}

class _VolumePopoverState extends State<_VolumePopover> {
  late int _v;
  @override
  void initState() {
    super.initState();
    _v = widget.state.volume;
  }

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 260,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              AppIcon('volume-2', size: 16, color: AppColors.txt2),
              const SizedBox(width: 8),
              const Text('音量',
                  style: TextStyle(fontSize: 13, color: AppColors.txt2)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Slider(
                  value: _v.toDouble(),
                  min: 0,
                  max: 100,
                  activeColor: AppColors.acc,
                  inactiveColor: AppColors.line,
                  onChanged: (v) {
                    setState(() => _v = v.round());
                    widget.state.volume = _v;
                    widget.state.notify();
                  },
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 42,
                child: Text('$_v%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.acc2)),
              ),
            ]),
          ]),
        ),
      );
}
