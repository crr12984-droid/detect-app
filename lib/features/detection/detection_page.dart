import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/device.dart';
import '../../core/wifi_scanner.dart';
import '../../core/ble_scanner.dart';
import '../../core/permissions.dart';
import '../positioning/positioning_page.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});
  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Device> _wifi = [];
  List<Device> _ble = [];
  bool _scanning = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final ok = await ensureScanPermissions();
    if (!ok && mounted) setState(() => _err = '需授予位置权限才能扫描');
    _scan();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    _err = '';
    try {
      // 定位服务（GPS）是否开启：安卓 11- 关闭时 WiFi/蓝牙必然扫不到
      final locOn = await isLocationServiceEnabled();
      if (!locOn) {
        _err = '未开启“定位服务 / GPS”。请在系统设置 → 位置信息 中打开，'
            '否则绝大多数安卓机型无法扫描 WiFi / 蓝牙。';
      }

      // 真实 WiFi 扫描：startScan 后系统需要数秒完成扫描，必须等待再取结果
      final w = WifiScanner();
      await w.start();
      await Future.delayed(const Duration(seconds: 3));
      _wifi = await w.getResults();

      // 真实蓝牙低功耗扫描：Android 12+ 会弹窗请求开启蓝牙
      final b = BleScanner();
      if (await b.supported) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {
          // 用户拒绝开启蓝牙时忽略，下面扫描自然为空
        }
        await for (final list in b.scan(timeout: const Duration(seconds: 5))) {
          _ble = list;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _err = '扫描出错: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Widget _tile(Device d) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: Icon(
            d.kind == DeviceKind.wifi ? Icons.wifi : Icons.bluetooth,
            color: const Color(0xFF22B8CF),
          ),
          title: Text(d.name),
          subtitle: Text('${d.brand}  ·  ${d.id}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${d.rssi} dBm',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${d.distance.toStringAsFixed(1)} m',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PositioningPage(device: d)),
          ),
        ),
      );

  Widget _list(List<Device> items, {String hint = ''}) {
    if (items.isEmpty) {
      return Center(
        padding: const EdgeInsets.all(16),
        child: Text(
          hint.isNotEmpty ? hint : '未发现设备，点击右上角重新扫描',
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) => _tile(items[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能检测'),
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'WiFi'), Tab(text: '蓝牙')],
        ),
      ),
      body: Column(
        children: [
          if (_err.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(8),
              child: Text(_err, style: const TextStyle(color: Colors.orange)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _list(_wifi),
                _list(_ble,
                    hint: '未发现蓝牙设备。请确认已开启蓝牙（系统设置或下拉快捷栏），并靠近待检测设备后重新扫描。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
