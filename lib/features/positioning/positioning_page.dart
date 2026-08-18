import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui_assets.dart';
import '../../models/device.dart';

/// 定位追踪页：信号卡 + 同心环定位器 + 信号详情 + 实时趋势曲线。
/// 全部读取 AppState（tracked / trend / maxRssi / dir），由 AppState 每秒刷新。
class PositioningPage extends StatelessWidget {
  final AppState state;
  const PositioningPage(this.state);

  @override
  Widget build(BuildContext context) {
    final d = state.tracked;
    if (d == null) {
      return const Center(child: Text('无追踪目标', style: TextStyle(color: AppColors.txt3)));
    }
    final isWifi = d.kind == DeviceKind.wifi;

    return Column(children: [
      // 头部（已移除右上角室内/室外文字）
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          _iconBtn('arrow-left', state.backToList),
          const SizedBox(width: 12),
          const Text('定位跟踪',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // 2×2 等分：四区域尺寸完全一致、上下左右严格对齐
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _sigCard(d)),
                  const SizedBox(width: 16),
                  Expanded(child: _detailCard(d, isWifi)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _locCard(d)),
                  const SizedBox(width: 16),
                  Expanded(child: _trendCard()),
                ],
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ---------- 四区域卡片（尺寸一致） ----------
  Widget _sigCard(Device d) => _card(
        icon: 'activity',
        title: '目标信号',
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(d.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${d.rssi}',
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppColors.acc2)),
                  const SizedBox(width: 6),
                  const Text('dBm',
                      style: TextStyle(fontSize: 14, color: AppColors.txt2)),
                ],
              ),
              const SizedBox(height: 12),
              _signalMeter(d.rssi),
              const SizedBox(height: 6),
            ]),
          ),
      );

  Widget _locCard(Device d) => _card(
        icon: 'crosshair',
        title: '定位',
        child: Column(children: [
          const SizedBox(height: 8),
          Expanded(child: Locator(rssi: d.rssi, maxRssi: state.maxRssi, dir: state.dir)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFFFF9F1C), '实时信号'),
              const SizedBox(width: 18),
              _legendDot(const Color(0xFFEF4444), '最大信号'),
            ],
          ),
        ]),
      );

  Widget _detailCard(Device d, bool isWifi) => _card(
        icon: 'info',
        title: '信号详情',
        child: _detailGrid(d, isWifi),
      );

  Widget _trendCard() => _card(
        icon: 'activity',
        title: '实时趋势曲线',
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TrendChart(data: state.trend),
        ),
      );

  Widget _card(
          {required String icon,
          required String title,
          required Widget child}) =>
      Container(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              AppIcon(icon, size: 16, color: AppColors.acc),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.txt2,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 10),
            Expanded(child: child),
          ],
        ),
      );

  /// 8 格信号条（与原型一致：clamp(round((rssi+100)/60*8),0,8)），随信号动态变化
  Widget _signalMeter(int rssi) {
    final n = ((rssi + 100) / 60 * 8).round().clamp(0, 8);
    final color = rssi >= state.indoorThr
        ? const Color(0xFFFACC15)
        : const Color(0xFF46536A);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (i) {
        final on = i < n;
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: on ? color : Colors.transparent,
            border: Border.all(color: const Color(0xFF46536A)),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _legendDot(Color c, String label) => Row(children: [
        Container(
            width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.txt2)),
      ]);

  /// 信号详情（紧凑 3 列，缩小行间距）；字段顺序与原型一致
  Widget _detailGrid(Device d, bool isWifi) {
    final first = _fmtTime(d.firstSeen);
    final rows = isWifi
        ? [
            ['名称', d.name],
            ['品牌', brandLabel(d.brand)],
            ['类型', d.wifiType == WifiType.direct
                ? 'WiFi Direct'
                : d.wifiType == WifiType.sta
                    ? 'STA'
                    : 'AP'],
            ['区域', state.isIndoor(d) ? '室内' : '室外'],
            ['距离', '${d.distance.toStringAsFixed(1)} m'],
            ['加密', d.info ?? '—'],
            ['信道', d.channel != null ? 'CH ${d.channel}' : '—'],
            ['发现时间', first],
            ['发现次数', '${d.seen} 次'],
            ['MAC', d.id],
          ]
        : [
            ['名称', d.name],
            ['品牌', '${brandLabel(d.brand)}${d.domestic ? '（国产）' : '（进口）'}'],
            ['品类', d.category.isEmpty ? '未知' : d.category],
            ['类型', radioTypeLabel(d.radioType)],
            ['区域', state.isIndoor(d) ? '室内' : '室外'],
            ['距离', '${d.distance.toStringAsFixed(1)} m'],
            ['发现时间', first],
            ['发现次数', '${d.seen} 次'],
            ['MAC', d.id],
          ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3.6,
        crossAxisSpacing: 14,
        mainAxisSpacing: 2,
      ),
      itemCount: rows.length,
      itemBuilder: (_, i) => _drow(rows[i][0], rows[i][1]),
    );
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  Widget _drow(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1B232E)))),
        child: Row(children: [
          Text(k, style: const TextStyle(fontSize: 12, color: AppColors.txt3)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.txt),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  Widget _iconBtn(String icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.panel2,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: AppIcon(icon, size: 20)),
        ),
      );
}

/// 同心环定位器：环=信号由强到弱，方向箭头=定位方向，实时(橙)/最大(红)双点重合=已找到。
class Locator extends StatelessWidget {
  final int rssi;
  final double maxRssi;
  final double dir;
  const Locator(
      {super.key,
      required this.rssi,
      required this.maxRssi,
      required this.dir});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => SizedBox(
          width: c.maxWidth,
          height: c.maxHeight,
          child: CustomPaint(
            painter: _LocatorPainter(rssi, maxRssi, dir),
          ),
        ),
      );
}

class _LocatorPainter extends CustomPainter {
  final int rssi;
  final double maxRssi;
  final double dir;
  _LocatorPainter(this.rssi, this.maxRssi, this.dir);

  double _rOf(double s) => 86 * (s / -100).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 2;
    final scale = size.width / 200;
    final rings = [90.0, 72.0, 54.0, 36.0, 18.0];
    final labels = [-100, -80, -60, -40, -20];

    final ringPaint = Paint()
      ..color = const Color(0x665E8A74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in rings) {
      canvas.drawCircle(Offset(c, c), r * scale, ringPaint);
    }
    final axisPaint = Paint()
      ..color = const Color(0x295E8A74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c, c - 96 * scale), Offset(c, c + 96 * scale), axisPaint);
    canvas.drawLine(Offset(c - 96 * scale, c), Offset(c + 96 * scale, c), axisPaint);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < rings.length; i++) {
      tp.text = TextSpan(
          text: '${labels[i]}',
          style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF6F8D7C)));
      tp.layout();
      tp.paint(canvas, Offset(c + 3 * scale, c - rings[i] * scale - 4 * scale));
    }
    canvas.drawCircle(Offset(c, c), 3 * scale,
        Paint()..color = const Color(0xFF5E6977));
    final rad = dir * pi / 180;
    final ux = cos(rad), uy = sin(rad);
    final ex = c + ux * 86 * scale, ey = c + uy * 86 * scale;
    // 方向线：无箭头虚线（对齐原型 .dir-line{stroke-dasharray:6 5}）
    final dirPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
        canvas, Offset(c, c), Offset(ex, ey), dirPaint, 6 * scale, 5 * scale);
    final rl = _rOf(rssi.toDouble());
    _dot(canvas, c + ux * rl * scale, c + uy * rl * scale, const Color(0xFFFF9F1C));
    final rm = _rOf(maxRssi);
    _dot(canvas, c + ux * rm * scale, c + uy * rm * scale, const Color(0xFFEF4444));
  }

  void _dot(Canvas canvas, double x, double y, Color color) {
    final glow = Paint()..color = color.withOpacity(0.9);
    canvas.drawCircle(Offset(x, y), 5.5, glow);
    canvas.drawCircle(Offset(x, y), 5.5,
        Paint()..color = color..style = PaintingStyle.fill);
  }

  /// 画一条虚线（起点→终点，按 dash/gap 分段）
  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      double dash, double gap) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1e-3) return;
    final ux = dx / len, uy = dy / len;
    var t = 0.0;
    while (t < len) {
      final end = (t + dash) < len ? (t + dash) : len;
      canvas.drawLine(Offset(a.dx + ux * t, a.dy + uy * t),
          Offset(a.dx + ux * end, a.dy + uy * end), paint);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LocatorPainter o) =>
      o.rssi != rssi || o.maxRssi != maxRssi || o.dir != dir;
}

/// 实时趋势曲线（Canvas）：Y 轴 0 → -100 dBm，X 轴 0..60s 网格，面积+折线+最新点。
class TrendChart extends StatelessWidget {
  final List<int> data;
  const TrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _TrendPainter(data),
        ),
      );
}

class _TrendPainter extends CustomPainter {
  final List<int> data;
  _TrendPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final padL = 42.0, padR = 12.0, padT = 14.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final yTop = 0.0, yBot = -100.0;
    double yOf(double v) => padT + ((yTop - v) / (yTop - yBot)) * plotH;

    final grid = Paint()..color = const Color(0xFF2A3340);
    final lbl = TextPainter(textDirection: TextDirection.ltr);
    for (final s in [0, -20, -40, -60, -80, -100]) {
      final y = yOf(s.toDouble());
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), grid);
      lbl.text = TextSpan(
          text: '$s', style: const TextStyle(fontSize: 10, color: Color(0xFF5E6977)));
      lbl.textAlign = TextAlign.right;
      lbl.layout();
      lbl.paint(canvas, Offset(padL - 6 - lbl.width, y - lbl.height / 2));
    }
    for (var t = 0; t <= 60; t += 5) {
      final gx = padL + (t / 60) * plotW;
      canvas.drawLine(Offset(gx, padT), Offset(gx, padT + plotH), grid);
      lbl.text = TextSpan(
          text: t == 60 ? '60s' : '$t',
          style: const TextStyle(fontSize: 9, color: Color(0xFF5E6977)));
      lbl.textAlign = TextAlign.center;
      lbl.layout();
      lbl.paint(canvas, Offset(gx - lbl.width / 2, size.height - 16));
    }

    final N = data.length;
    if (N < 2) return;
    final step = plotW / (N - 1);
    final pts = [for (var i = 0; i < N; i++) Offset(padL + i * step, yOf(data[i].toDouble()))];

    final areaPath = Path()
      ..moveTo(pts[0].dx, padT + plotH)
      ..lineTo(pts[0].dx, pts[0].dy);
    for (final p in pts) areaPath.lineTo(p.dx, p.dy);
    areaPath.lineTo(pts.last.dx, padT + plotH);
    areaPath.close();
    canvas.drawPath(
        areaPath,
        Paint()
          ..color = const Color(0x4222B8CF)
          ..style = PaintingStyle.fill);
    final linePath = Path()
      ..moveTo(pts[0].dx, pts[0].dy);
    for (final p in pts) linePath.lineTo(p.dx, p.dy);
    canvas.drawPath(
        linePath,
        Paint()
          ..color = const Color(0xFF22B8CF)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(pts.last, 3.5, Paint()..color = const Color(0xFF22B8CF));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter o) => o.data != data;
}
