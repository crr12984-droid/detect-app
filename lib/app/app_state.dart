import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/report.dart';
import '../core/wifi_scanner.dart';
import '../core/ble_scanner.dart';
import '../core/device_classifier.dart';
import '../core/company_db.dart';
import '../core/permissions.dart';

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
  final BleScanner _ble = BleScanner(); // 缓存 BluetoothDevice，供连接读型号
  final Set<String> _modelTried = {}; // 已尝试读型号的 MAC，避免重复连接
  bool _resolving = false;

  // 定位
  Device? tracked;
  List<int> trend = [];
  double maxRssi = -35;
  double dir = 0;
  Timer? _posTimer;
  int _prevRssi = -100; // 上一次 tick 的信号值，用于信号增强提示音

  // 列表排序：信号强度 / 距离，可点击切换升/降序
  String wifiSortKey = 'rssi';
  int wifiSortDir = -1; // -1 降序, 1 升序
  String bleSortKey = 'rssi';
  int bleSortDir = -1;

  // 顶部绿色提示横幅
  String? bannerMsg;

  VoidCallback? onChanged;
  bool _alive = true;

  AppState() {
    loadReports();
  }

  /// 退出登录：停止扫描与定位、清空追踪目标、回到登录页
  void logout() {
    stopScan();
    stopPosition();
    tracked = null;
    trend = [];
    authed = false;
    overlay = null;
    section = 0;
    notify();
  }

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
    // 申请扫描所需权限（蓝牙扫描/连接 + 定位），并确认定位服务已开启。
    // 普通安卓权限无法 monitor-mode 嗅探，未授权时扫描将返回空。
    final granted = await ensureScanPermissions();
    final locOn = await isLocationServiceEnabled();
    if (!granted || !locOn) {
      showBanner(locOn
          ? '扫描需要蓝牙与定位权限，请授予后重试'
          : '请先在系统设置中开启定位服务');
    }
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
      // 后台并行解析型号/名称（连接读 GATT），不阻塞扫描刷新
      _modelTimer?.cancel();
      _modelTimer =
          Timer.periodic(const Duration(seconds: 4), (_) => _maybeResolveModels());
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
  Timer? _modelTimer; // 后台型号解析定时器（与扫描并行，避免阻塞扫描刷新）
  Future<void> _bleLoop() async {
    if (!scanning || detType != DeviceKind.ble) return;
    if (!(await _ble.supported)) return;
    _bleSub?.cancel();
    _bleSub = FlutterBluePlus.scanResults.listen((list) {
      if (!scanning || detType != DeviceKind.ble) return;
      ble = _ble.mapResults(list);
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
    _modelTimer?.cancel();
    _modelTimer = null;
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
    _prevRssi = d.rssi;
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
    // 声音提示：信号增强（变强 ≥3dBm）时短促提示音，便于靠近目标时定位
    if (sound && nr - _prevRssi >= 3) _beep(3);
    _prevRssi = nr;
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

  // ---------- 精确型号/名称（连接后读 GATT 设备信息服务 0x180A） ----------
  /// 后台批次解析型号：每轮最多解析若干台，仅「成功」才计入 _modelTried，
  /// 失败则保留在待解析集合以便重试（解决苹果设备因连接被拒而永久看不到型号的问题）。
  final Map<String, int> _modelFails = {}; // id -> 连续失败次数

  Future<void> _maybeResolveModels() async {
    if (_resolving) return;
    int budget = 2; // 每轮最多解析 2 台，避免占用过多连接时间
    for (final d in ble) {
      if (budget <= 0) break;
      final nameUnknown =
          d.name.isEmpty || d.name.contains('未知设备') || d.name == '(未知设备)';
      final needs =
          d.model == null && (d.brand == 'Apple' || d.brand == '未知' || nameUnknown);
      if (!needs || _modelTried.contains(d.id)) continue;
      if ((_modelFails[d.id] ?? 0) >= 3) continue; // 连续失败 3 次后放弃
      _resolving = true;
      bool ok = false;
      try {
        ok = await resolveModel(d);
      } catch (_) {
        ok = false;
      } finally {
        _resolving = false;
      }
      if (ok) {
        _modelTried.add(d.id);
        _modelFails.remove(d.id);
        budget--;
      } else {
        _modelFails[d.id] = (_modelFails[d.id] ?? 0) + 1;
      }
    }
  }

  /// 连接设备读取设备信息服务(0x180A)：0x2A24=型号、0x2A00=名称、
  /// 0x2A29=厂商、0x2A01=外观(品类)。返回是否成功取到任何信息。
  Future<bool> resolveModel(Device d) async {
    if (d.kind != DeviceKind.ble) return false;
    final bd = _ble.deviceFor(d.id);
    if (bd == null) return false;
    String? model, devName, mfr, serial;
    int? appearance;
    int? pnpVendorId; // PnP ID(0x2A50) 中 vendorId(SIG 公司码)
    bool got = false;
    try {
      await bd.connect(timeout: const Duration(seconds: 6));
      final services = await bd.discoverServices();
      for (final s in services) {
        if (!s.uuid.str.toUpperCase().contains('180A')) continue;
        for (final c in s.characteristics) {
          final u = c.uuid.str.toUpperCase();
          try {
            if (u.contains('2A24')) {
              model = String.fromCharCodes(await c.read()).trim();
              if (model?.isNotEmpty == true) got = true;
            } else if (u.contains('2A00')) {
              devName = String.fromCharCodes(await c.read()).trim();
              if (devName?.isNotEmpty == true) got = true;
            } else if (u.contains('2A29')) {
              mfr = String.fromCharCodes(await c.read()).trim();
            } else if (u.contains('2A01')) {
              final b = await c.read();
              if (b.length >= 2) appearance = b[0] | (b[1] << 8);
            } else if (u.contains('2A25')) {
              // Serial Number：设备唯一指纹（用于去重/报告列具体序列）
              serial = String.fromCharCodes(await c.read()).trim();
              if (serial?.isNotEmpty == true) got = true;
            } else if (u.contains('2A50')) {
              // PnP ID：[vendorIdSource, vendorId(2 LE), productId(2 LE), productVersion(2 LE)]
              final b = await c.read();
              if (b.length >= 7) pnpVendorId = b[1] | (b[2] << 8);
            }
          } catch (_) {}
        }
      }
      await bd.disconnect();
    } catch (_) {
      return false;
    }
    if (!got) return false; // 未读到任何信息：视为失败，待重试
    final i = ble.indexWhere((x) => x.id == d.id);
    if (i < 0) return false;
    final pretty =
        (model != null && model!.isNotEmpty) ? appleMarketingName(model!) : null;
    // 仅当当前名称为兜底（未知/品牌品类拼接）时用 GATT 设备名覆盖
    final cur = ble[i].name;
    final nameUnknown = cur.isEmpty ||
        cur == '(未知设备)' ||
        cur.contains('未知设备') ||
        (cur.contains(ble[i].brand) &&
            ble[i].category.isNotEmpty &&
            cur == '${ble[i].brand} ${ble[i].category}');
    final newName =
        (devName != null && devName!.isNotEmpty && nameUnknown) ? devName! : null;
    // 广播未给出品类时，用 0x2A01 外观补强
    String newCat = ble[i].category;
    if (newCat.isEmpty && appearance != null) {
      final ap = appearanceCategory(appearance);
      if (ap.isNotEmpty) newCat = ap;
    }
    // 厂商字段补强品牌（如 0x2A29=Apple）
    String newBrand = ble[i].brand;
    bool newDomestic = ble[i].domestic;
    if (newBrand == '未知' && mfr != null && mfr!.toLowerCase().contains('apple')) {
      newBrand = 'Apple';
      newDomestic = false;
    }
    // PnP ID(0x2A50) 的 Vendor ID 是 SIG 公司码，与广播 Company ID 同空间 → 交叉验证品牌
    if (newBrand == '未知' && pnpVendorId != null) {
      final pb = brandFromCompanyId(pnpVendorId);
      if (pb != '未知') {
        newBrand = pb;
        newDomestic = isDomesticBrand(pb);
      }
    }
    ble[i] = ble[i].copyWith(
      model: pretty ?? ble[i].model,
      name: newName ?? ble[i].name,
      category: newCat,
      brand: newBrand,
      domestic: newDomestic,
      serial: serial ?? ble[i].serial,
    );
    notify();
    return true;
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
    saveReports();
    showBanner('报告已导出');
  }

  /// 从本地文件载入已导出报告（应用启动与构造时调用）
  static const String _reportsFile = 'reports.json';
  Future<void> loadReports() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$_reportsFile');
      if (await f.exists()) {
        final txt = await f.readAsString();
        final list = jsonDecode(txt) as List;
        reports = list.map((e) => Report.fromJson(e as Map<String, dynamic>)).toList();
        notify();
      }
    } catch (_) {}
  }

  /// 将当前报告列表持久化到本地文件
  Future<void> saveReports() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$_reportsFile');
      await f.writeAsString(jsonEncode(reports.map((r) => r.toJson()).toList()));
    } catch (_) {}
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

  void deleteReport(int id) {
    reports.removeWhere((r) => r.id == id);
    saveReports();
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
