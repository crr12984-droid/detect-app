import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device.dart';
import '../models/report.dart';
import '../core/wifi_scanner.dart';
import '../core/ble_scanner.dart';

/// 全局应用状态：导航、扫描、定位、报告、设置。
/// 由 AppShell 持有并注入各界面；任何变更调用 notify() 触发重建。
class AppState {
  int section = 0; // 0 智能检测, 1 报告管理, 2 系统设置
  String? overlay; // null | 'detection' | 'position' | 'preview'
  DeviceKind? detType;
  List<Device> wifi = [];
  List<Device> ble = [];
  List<Report> reports = [];
  Report? previewReport;

  // 设置
  int thresholdDbm = -60;
  double indoorThr = 2.0;
  bool sentinel = false;
  bool sound = true;
  String devTime = '';
  int volume = 60;

  // 扫描
  bool scanning = false;
  Timer? _scanTimer;

  // 定位
  Device? tracked;
  List<int> trend = [];
  double maxRssi = -35;
  double dir = 0;
  Timer? _posTimer;

  VoidCallback? onChanged;
  bool _alive = true;

  // 报告管理
  bool selMode = false;
  Set<int> selReports = {};

  // 蓝牙列表筛选：all / foreign / apple / seized
  String btFilter = 'all';
  void setBtFilter(String f) {
    btFilter = f;
    notify();
  }

  List<Device> get currentList =>
      detType == DeviceKind.wifi ? wifi : ble;

  List<Device> get filteredList {
    final list = currentList;
    if (detType == DeviceKind.ble) {
      if (btFilter == 'foreign') return list.where((d) => !d.domestic).toList();
      if (btFilter == 'apple') return list.where((d) => d.brand == 'Apple').toList();
      if (btFilter == 'seized') return list.where((d) => d.seized).toList();
    }
    return list;
  }

  void notify() {
    if (_alive) onChanged?.call();
  }

  bool isIndoor(Device d) => d.distance >= indoorThr;

  // ---------- 扫描 ----------
  Future<void> openDetection(DeviceKind type) async {
    detType = type;
    overlay = 'detection';
    notify();
    await startScan();
  }

  Future<void> startScan() async {
    scanning = true;
    notify();
    await _doScan();
    notify();
    _scanTimer?.cancel();
    _scanTimer =
        Timer.periodic(const Duration(seconds: 3), (_) async {
      await _doScan();
      notify();
    });
  }

  Future<void> _doScan() async {
    if (detType == DeviceKind.wifi) {
      final w = WifiScanner();
      await w.start();
      await Future.delayed(const Duration(seconds: 3));
      wifi = await w.getResults();
    } else if (detType == DeviceKind.ble) {
      final b = BleScanner();
      if (await b.supported) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
        await for (final list in b.scan(timeout: const Duration(seconds: 5))) {
          ble = list;
        }
      }
    }
  }

  void stopScan() {
    scanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    notify();
  }

  void toggleScan() {
    if (scanning) {
      stopScan();
    } else {
      startScan();
    }
  }

  void backToApp() {
    stopScan();
    overlay = null;
    section = 0;
    notify();
  }

  // ---------- 定位 ----------
  Future<void> openPosition(Device d) async {
    stopScan();
    tracked = d;
    maxRssi = (d.rssi - 6).clamp(-100, -35).toDouble();
    dir = (DateTime.now().millisecondsSinceEpoch % 360).toDouble();
    trend = List.generate(60, (_) => d.rssi);
    overlay = 'position';
    notify();
    _posTimer?.cancel();
    _posTimer = Timer.periodic(const Duration(seconds: 1), (_) => _posTick());
    await _posTick();
  }

  Future<void> _posTick() async {
    if (tracked == null) return;
    int? nr;
    if (tracked!.kind == DeviceKind.wifi) {
      final w = WifiScanner();
      await w.start();
      final list = await w.getResults();
      final f = list.where((x) => x.id == tracked!.id).isNotEmpty
          ? list.firstWhere((x) => x.id == tracked!.id)
          : null;
      nr = f?.rssi;
    } else {
      final b = BleScanner();
      if (await b.supported) {
        if (FlutterBluePlus.isScanningNow) {
          try {
            await FlutterBluePlus.stopScan();
          } catch (_) {}
        }
        await for (final list in b.scan(timeout: const Duration(seconds: 2))) {
          final f = list.where((x) => x.id == tracked!.id).isNotEmpty
              ? list.firstWhere((x) => x.id == tracked!.id)
              : null;
          nr = f?.rssi;
        }
      }
    }
    if (nr != null) {
      tracked = tracked!.copyWith(rssi: nr, seen: tracked!.seen + 1);
      maxRssi = max(maxRssi, nr.toDouble());
      dir = (dir + (DateTime.now().millisecond % 12 - 6) + 360) % 360;
      trend.add(nr);
      if (trend.length > 60) trend.removeAt(0);
    }
    notify();
  }

  void backToList() {
    _posTimer?.cancel();
    _posTimer = null;
    overlay = 'detection';
    notify();
    startScan();
  }

  void stopPosition() {
    _posTimer?.cancel();
    _posTimer = null;
  }

  // ---------- 查扣 ----------
  void detain(Device d) {
    final list = detType == DeviceKind.wifi ? wifi : ble;
    final i = list.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      list[i] = list[i].copyWith(seized: true);
      notify();
    }
  }

  // ---------- 报告 ----------
  void exportReport() {
    if (detType == null) return;
    final list = detType == DeviceKind.wifi ? wifi : ble;
    final isWifi = detType == DeviceKind.wifi;
    final name = isWifi ? 'WiFi检测' : '国外设备检测';
    final now = DateTime.now();
    final ts =
        '${now.year}-${_p(now.month)}-${_p(now.day)} ${_p(now.hour)}:${_p(now.minute)}';
    reports.insert(
        0,
        Report(
          id: now.millisecondsSinceEpoch,
          name: name,
          label: name,
          type: isWifi ? 'wifi' : 'ble',
          time: ts,
          count: list.length,
          devices: list.map((d) => d.copyWith()).toList(),
          indoorThr: indoorThr,
        ));
    notify();
  }

  void previewReport(Report r) {
    previewReport = r;
    overlay = 'preview';
    notify();
  }

  void backFromPreview() {
    overlay = null;
    section = 1;
    notify();
  }

  // ---------- 报告管理 ----------
  void toggleSelMode() {
    selMode = !selMode;
    if (!selMode) selReports.clear();
    notify();
  }

  void toggleSel(int id) {
    if (selReports.contains(id)) {
      selReports.remove(id);
    } else {
      selReports.add(id);
    }
    notify();
  }

  void toggleSelAll() {
    if (selReports.length == reports.length) {
      selReports.clear();
    } else {
      selReports = reports.map((r) => r.id).toSet();
    }
    notify();
  }

  void deleteReport(int id) {
    reports.removeWhere((r) => r.id == id);
    selReports.remove(id);
    notify();
  }

  void batchDelete() {
    reports.removeWhere((r) => selReports.contains(r.id));
    selReports.clear();
    selMode = false;
    notify();
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  void dispose() {
    _alive = false;
    _scanTimer?.cancel();
    _posTimer?.cancel();
    onChanged = null;
  }
}
