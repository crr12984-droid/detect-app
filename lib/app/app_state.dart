import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  int thresholdDbm = -60; // 告警阈值（dBm）
  int indoorThr = -60; // 室内判定阈值（dBm）：信号强度 ≥ 该值判为室内
  bool sentinel = false; // 哨兵模式：加快扫描与上报
  bool sound = true; // 声音告警
  String devTime = '';
  int volume = 60;
  bool muted = false; // 音量静音
  bool authed = false; // 是否已登录

  // 扫描
  bool scanning = false;
  Timer? _scanTimer;
  Timer? _bannerTimer;

  // 定位
  Device? tracked;
  List<int> trend = [];
  double maxRssi = -35;
  double dir = 0;
  Timer? _posTimer;

  // 列表排序：信号强度 / 距离，可点击切换升/降序
  String wifiSortKey = 'rssi';
  int wifiSortDir = -1; // -1 降序, 1 升序
  String bleSortKey = 'rssi';
  int bleSortDir = -1;

  // 顶部绿色提示横幅
  String? bannerMsg;

  VoidCallback? onChanged;
  bool _alive = true;

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

  /// 当前展示列表（已按所选列排序）
  List<Device> get displayList {
    final base = detType == DeviceKind.wifi ? wifi : filteredList;
    return _sort(base);
  }

  List<Device> _sort(List<Device> list) {
    final key = detType == DeviceKind.wifi ? wifiSortKey : bleSortKey;
    final dir = detType == DeviceKind.wifi ? wifiSortDir : bleSortDir;
    final l = [...list];
    l.sort((a, b) {
      final cmp = key == 'dist'
          ? a.distance.compareTo(b.distance)
          : a.rssi.compareTo(b.rssi);
      return cmp * dir;
    });
    return l;
  }

  void setSort(DeviceKind kind, String key) {
    final isWifi = kind == DeviceKind.wifi;
    final k = isWifi ? wifiSortKey : bleSortKey;
    if (k == key) {
      if (isWifi) {
        wifiSortDir *= -1;
      } else {
        bleSortDir *= -1;
      }
    } else {
      if (isWifi) {
        wifiSortKey = key;
        wifiSortDir = -1;
      } else {
        bleSortKey = key;
        bleSortDir = -1;
      }
    }
    notify();
  }

  void notify() {
    if (_alive) onChanged?.call();
  }

  /// 室内/室外判定依据信号强度阈值（dBm）
  bool isIndoor(Device d) => d.rssi >= indoorThr;

  // ---------- 扫描 ----------
  Future<void> openDetection(DeviceKind type) async {
    detType = type;
    overlay = 'detection';
    notify();
    await startScan();
  }

  Duration _bleTimeout() =>
      sentinel ? const Duration(seconds: 2) : const Duration(seconds: 4);
  Duration _posInterval() => sentinel
      ? const Duration(milliseconds: 500)
      : const Duration(seconds: 1);

  Future<void> startScan() async {
    scanning = true;
    notify();
    if (detType == DeviceKind.wifi) {
      _wifiLoop();
    } else {
      _bleLoop();
    }
  }

  /// 连续 WiFi 扫描：每次重新触发扫描并读取结果，实时刷新列表
  Future<void> _wifiLoop() async {
    while (scanning && detType == DeviceKind.wifi) {
      try {
        await WifiScanner().start();
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!scanning || detType != DeviceKind.wifi) return;
        wifi = await WifiScanner().getResults();
        notify();
      } catch (_) {}
      await Future.delayed(
          sentinel ? const Duration(milliseconds: 800) : const Duration(milliseconds: 1800));
    }
  }

  /// 连续 BLE 扫描（每次超时后自动续扫），通过订阅 scanResults 实时上报周边设备
  StreamSubscription? _bleSub;
  Future<void> _bleLoop() async {
    if (!scanning || detType != DeviceKind.ble) return;
    if (!(await BleScanner().supported)) return;
    _bleSub?.cancel();
    _bleSub = FlutterBluePlus.scanResults.listen((list) {
      if (!scanning || detType != DeviceKind.ble) return;
      ble = list;
      notify();
    });
    while (scanning && detType == DeviceKind.ble) {
      try {
        if (!FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.startScan(
              timeout: _bleTimeout(), androidUsesFineLocation: false);
        }
        // 等待本次扫描自然结束（超时会自动停止）
        await FlutterBluePlus.isScanning
            .where((s) => !s)
            .first
            .timeout(_bleTimeout() + const Duration(seconds: 1));
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  void stopScan() {
    scanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    try {
      if (FlutterBluePlus.isScanningNow) FlutterBluePlus.stopScan();
    } catch (_) {}
    _bleSub?.cancel();
    _bleSub = null;
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
    maxRssi = d.rssi.toDouble();
    dir = (DateTime.now().millisecondsSinceEpoch % 360).toDouble();
    trend = List.generate(60, (_) => d.rssi);
    overlay = 'position';
    notify();
    _posTimer?.cancel();
    _posTimer = Timer.periodic(_posInterval(), (_) => _posTick());
    _posTick();
  }

  void _posTick() {
    if (tracked == null) return;
    final list = tracked!.kind == DeviceKind.wifi ? wifi : ble;
    final f = list.where((x) => x.id == tracked!.id).isNotEmpty
        ? list.firstWhere((x) => x.id == tracked!.id)
        : null;
    int nr = f?.rssi ?? tracked!.rssi;
    // 在真实值基础上做 ±2 抖动，使信号格/趋势保持动态（不累积漂移）
    nr = (nr + (Random().nextInt(5) - 2)).clamp(-100, -30);
    tracked = tracked!.copyWith(rssi: nr, seen: tracked!.seen + 1);
    maxRssi = max(maxRssi, nr.toDouble());
    dir = (dir + (Random().nextDouble() * 10 - 5) + 360) % 360;
    trend.add(nr);
    if (trend.length > 60) trend.removeAt(0);
    // 声音提示：信号强时急促
    if (sound && nr >= indoorThr) _beep(nr >= -45 ? 3 : 2);
    notify();
  }

  void _beep(int times) {
    for (var i = 0; i < times; i++) {
      Future.delayed(Duration(milliseconds: i * 120), () {
        try {
          SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      });
    }
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
    showBanner('报告已导出');
  }

  void showBanner(String msg) {
    bannerMsg = msg;
    notify();
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 2), () {
      bannerMsg = null;
      notify();
    });
  }

  void openPreview(Report r) {
    previewReport = r;
    overlay = 'preview';
    notify();
  }

  void backFromPreview() {
    overlay = null;
    section = 1;
    notify();
  }

  // ---------- 工具 ----------
  void toggleMute() {
    muted = !muted;
    notify();
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  void dispose() {
    _alive = false;
    _scanTimer?.cancel();
    _posTimer?.cancel();
    _bannerTimer?.cancel();
    _bleSub?.cancel();
    onChanged = null;
  }
}
