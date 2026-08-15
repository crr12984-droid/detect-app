import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/device.dart';
import '../../core/wifi_scanner.dart';
import '../../core/ble_scanner.dart';

/// 定位追踪页：进入后持续（每 1 秒）重新扫描，刷新该设备的真实 RSSI，
/// 并绘制实测信号趋势。
class PositioningPage extends StatefulWidget {
  final Device device;
  const PositioningPage({super.key, required this.device});
  @override
  State<PositioningPage> createState() => _PositioningPageState();
}

class _PositioningPageState extends State<PositioningPage> {
  late Device _d;
  List<int> _history = [];
  Timer? _timer;
  bool _found = true;

  @override
  void initState() {
    super.initState();
    _d = widget.device;
    _history = [_d.rssi];
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    _refresh();
  }

  Future<void> _refresh() async {
    Device? found;
    if (_d.kind == DeviceKind.wifi) {
      final w = WifiScanner();
      await w.start();
      final list = await w.getResults();
      if (list.where((x) => x.id == _d.id).isNotEmpty) {
        found = list.firstWhere((x) => x.id == _d.id);
      }
    } else {
      final b = BleScanner();
      if (await b.supported) {
        if (FlutterBluePlus.isScanningNow) {
          try {
            await FlutterBluePlus.stopScan();
          } catch (_) {}
        }
        await for (final list in b.scan(timeout: const Duration(seconds: 2))) {
          if (list.where((x) => x.id == _d.id).isNotEmpty) {
            found = list.firstWhere((x) => x.id == _d.id);
          }
        }
      }
    }
    if (!mounted) return;
    if (found == null) {
      setState(() => _found = false);
      return;
    }
    final updated = _d.copyWith(rssi: found!.rssi, seen: _d.seen + 1);
    _history.add(updated.rssi);
    if (_history.length > 60) _history.removeAt(0);
    setState(() {
      _d = updated;
      _found = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _bars() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(8, (i) {
          final on = i < _d.bars;
          return Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFFACC15) : Colors.transparent,
              border: Border.all(color: const Color(0xFF46536A)),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.grey)),
            Text(v),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('定位追踪'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_d.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${_d.brand}  ·  ${_d.id}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Text('${_d.rssi} dBm',
                style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22B8CF))),
            const SizedBox(height: 8),
            _bars(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('距离估算', '${_d.distance.toStringAsFixed(1)} m'),
                    _row('发现次数', '${_d.seen}'),
                    if (_d.info != null) _row('加密/信息', _d.info!),
                    _row('状态',
                        _found ? '信号锁定中' : '暂未出现（可能离开范围）'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('信号趋势（实测 RSSI）',
                    style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 8),
            Card(
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(painter: _TrendPainter(_history)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<int> data;
  _TrendPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFF22B8CF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final n = data.length;
    final step = size.width / (n - 1);
    double yOf(int v) {
      final t = ((v + 100) / 70).clamp(0.0, 1.0);
      return size.height - t * size.height;
    }

    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = i * step;
      final y = yOf(data[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.data != data;
}
