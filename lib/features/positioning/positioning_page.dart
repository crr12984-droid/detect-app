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
    final indoor = state.isIndoor(d);

    return Column(children: [
      // 头部
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          _iconBtn('arrow-left', state.backToList),
          const SizedBox(width: 12),
          const Text('定位跟踪',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: indoor
                  ? AppColors.acc.withOpacity(0.13)
                  : AppColors.ok.withOpacity(0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(indoor ? '室内' : '室外',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: indoor
                        ? const Color(0xFF8FB6FF)
                        : const Color(0xFF5FCA86))),
          ),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (ctx, c) {
            final two = c.maxWidth > 720;
            final left = _leftCol(d, isWifi, indoor);
            final right = _rightCol(d, isWifi);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: two
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 16),
                        Expanded(child: right),
                      ],
                    )
                  : Column(children: [
                      left,
                      const SizedBox(height: 16),
                      right,
                    ]),
            );
          },
        ),
      ),
    ]);
  }

  // ---------- 左栏 ----------
  Widget _leftCol(Device d, bool isWifi, bool indoor) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 目标信号卡
          _card(
            icon: 'activity',
            title: '目标信号',
            child: Column(children: [
              const SizedBox(height: 6),
              Text(d.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
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
            ]),
          ),
          const SizedBox(height: 16),
          // 定位器卡
          _card(
            icon: 'crosshair',
            title: '定位',
            flex: true,
            child: Column(children: [
              const SizedBox(height: 8),
              Locator(
                rssi: d.rssi,
                maxRssi: state.maxRssi,
                dir: state.dir,
              ),
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
          ),
        ],
      );

  // ---------- 右栏 ----------
  Widget _rightCol(Device d, bool isWifi) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            icon: 'info',
            title: '信号详情',
            child: _detailGrid(d, isWifi),
          ),
          const SizedBox(height: 16),
          _card(
            icon: 'activity',
            title: '实时趋势曲线',
            flex: true,
            child: SizedBox(
              height: 200,
              child: TrendChart(data: state.trend),
            ),
          ),
        ],
      );

  Widget _card(
          {required String icon,
          required String title,
          required Widget child,
          bool flex = false}) =>
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  /// 8 格信号条（与原型 rssiLevel 公式一致：clamp(round((rssi+100)/60*8),0,8)）
  Widget _signalMeter(int rssi) {
    final n = ((rssi + 100) / 60 * 8).round().clamp(0, 8);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (i) {
        final on = i < n;
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFFACC15) : Colors.transparent,
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

  Widget _detailGrid(Device d, bool isWifi) {
    final rows = isWifi
        ? [
            ['名称', d.name],
            ['品牌', d.brand],
            ['类型', d.category.isEmpty ? '路由器' : d.category],
            ['区域', state.isIndoor(d) ? '室内' : '室外'],
            ['距离', '${d.distance.toStringAsFixed(1)} m'],
            ['加密', d.info ?? '—'],
            ['发现时间', _fmtTime(d.firstSeen)],
            ['发现次数', '${d.seen} 次'],
            ['BSSID', d.id],
          ]
        : [
            ['名称', d.name],
            ['品牌', '${d.brand}${d.domestic ? '（国产）' : '（进口）'}'],
            ['品类', d.category.isEmpty ? '未知' : d.category],
            ['区域', state.isIndoor(d) ? '室内' : '室外'],
            ['距离', '${d.distance.toStringAsFixed(1)} m'],
            ['发现时间', _fmtTime(d.firstSeen)],
            ['发现次数', '${d.seen} 次'],
            ['MAC', d.id],
          ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.2,
        crossAxisSpacing: 18,
      ),
      itemCount: rows.length,
      itemBuilder: (_, i) => _drow(rows[i][0], rows[i][1]),
    );
  }

  Widget _drow(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1B232E)))),
        child: Row(children: [
          Text(k, style: const TextStyle(fontSize: 12.5, color: AppColors.txt3)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12.5,
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

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
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
  Widget build(BuildContext context) => SizedBox(
        width: 200,
        height: 200,
        child: CustomPaint(
          painter: _LocatorPainter(rssi, maxRssi, dir),
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

    // 同心环
    final ringPaint = Paint()
      ..color = const Color(0x665E8A74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in rings) {
      canvas.drawCircle(Offset(c, c), r * scale, ringPaint);
    }
    // 十字轴
    final axisPaint = Paint()
      ..color = const Color(0x295E8A74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c, c - 96 * scale), Offset(c, c + 96 * scale), axisPaint);
    canvas.drawLine(Offset(c - 96 * scale, c), Offset(c + 96 * scale, c), axisPaint);
    // 环标签
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < rings.length; i++) {
      tp.text = TextSpan(
          text: '${labels[i]}',
          style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF6F8D7C)));
      tp.layout();
      tp.paint(canvas, Offset(c + 3 * scale, c - rings[i] * scale - 4 * scale));
    }
    // 中心点
    canvas.drawCircle(Offset(c, c), 3 * scale,
        Paint()..color = const Color(0xFF5E6977));
    // 方向箭头
    final rad = dir * pi / 180;
    final ux = cos(rad), uy = sin(rad);
    final ex = c + ux * 86 * scale, ey = c + uy * 86 * scale;
    final arrowPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(c, c), Offset(ex, ey), arrowPaint);
    // 箭头头部
    final ah = 7.0 * scale;
    final ang = atan2(uy, ux);
    canvas.drawLine(
        Offset(ex, ey),
        Offset(ex - ah * cos(ang - 0.5), ey - ah * sin(ang - 0.5)),
        arrowPaint);
    canvas.drawLine(
        Offset(ex, ey),
        Offset(ex - ah * cos(ang + 0.5), ey - ah * sin(ang + 0.5)),
        arrowPaint);
    // 实时点（橙）
    final rl = _rOf(rssi.toDouble());
    _dot(canvas, c + ux * rl * scale, c + uy * rl * scale, const Color(0xFFFF9F1C));
    // 最大点（红）
    final rm = _rOf(maxRssi);
    _dot(canvas, c + ux * rm * scale, c + uy * rm * scale, const Color(0xFFEF4444));
  }

  void _dot(Canvas canvas, double x, double y, Color color) {
    final glow = Paint()..color = color.withOpacity(0.9);
    canvas.drawCircle(Offset(x, y), 5.5, glow);
    canvas.drawCircle(Offset(x, y), 5.5,
        Paint()..color = color..style = PaintingStyle.fill);
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

    // 网格 + Y 轴刻度
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
    // X 轴分段（每 5s）
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

    // 面积
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
    // 折线
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
    // 最新点
    canvas.drawCircle(pts.last, 3.5, Paint()..color = const Color(0xFF22B8CF));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter o) => o.data != data;
}
