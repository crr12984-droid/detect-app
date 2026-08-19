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
import '../core/classic_bt_scanner.dart';
import '../core/device_classifier.dart';
import '../core/company_db.dart';
import '../core/device_store.dart';
import '../core/permissions.dart';

/// 全局应用状态：导航、扫描、定位、报告、设置。
/// 由 AppShell 持有并注入各界面；任何变更调用 notify() 触发重建。
class AppState {
  int section = 0; // 0 智能检测, 1 报告管理, 2 系统设置
  String? overlay; // null | 'detection' | 'position' | 'preview'
  DeviceKind? detType;
  // 设备表（内存索引 id→Device，界面的唯一数据源）。
  // 增量合并：新增追加、信号/距离变化更新、超时置灰、置灰超时删除。
  final Map<String, Device> _wifiMap = {};
  final Map<String, Device> _bleMap = {};
  List<Device> get wifi => _wifiMap.values.toList();
  List<Device> get ble => _bleMap.values.toList();
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
  Timer? _houseTimer; // 周期检查：置灰 / 删除超时设备
  final BleScanner _ble = BleScanner(); // 缓存 BluetoothDevice，供连接读型号
  final ClassicBtScanner _classicBt = ClassicBtScanner(); // 经典蓝牙 discovery
  final Set<String> _modelTried = {}; // 已尝试读型号的 MAC，避免重复连接
  bool _resolving = false;

  // 置灰/删除阈值
  static const Duration _staleAfter = Duration(minutes: 1); // 无上报超此 → 置灰
  static const Duration _removeAfter = Duration(minutes: 2); // 置灰后超此 → 删除

  // 定位
  Device? tracked;
  List<int> trend = [];
  double maxRssi = -35;
  double dir = 0;
  Timer? _posTimer;
  Timer? _beepTimer; // 定位追踪嘀嘀声节奏定时器
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
    _wifiMap.clear();
    _bleMap.clear();
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
      // 置灰设备恒排末尾（无论排序键/方向）
      if (a.stale != b.stale) return a.stale ? 1 : -1;
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
    // 清空本次会话内存表，从数据库恢复历史设备（恢复后标记置灰，避免干扰新扫描）
    if (type == DeviceKind.wifi) {
      _wifiMap.clear();
    } else {
      _bleMap.clear();
    }
    final saved = await DeviceStore.loadAll(type);
    for (final d in saved) {
      d.stale = true; // 历史设备上次上报已超时，先置灰；本次重新发现会恢复活跃
      if (type == DeviceKind.wifi) {
        _wifiMap[d.id] = d;
      } else {
        _bleMap[d.id] = d;
      }
    }
    _startHousekeeping();
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
      // BLE 主通道 + 经典蓝牙补充通道（并行），型号解析在扫描回调里立即触发
      _bleLoop();
      _classicLoop();
    }
  }

  /// 增量合并一轮扫描结果：新增→追加；已有→更新信号/距离/时间戳（信号变化才刷新）。
  void _mergeInto(Map<String, Device> map, List<Device> fresh) {
    for (final d in fresh) {
      final ex = map[d.id];
      if (ex == null) {
        // 新增：直接入库
        map[d.id] = d;
        DeviceStore.upsert(d);
        continue;
      }
      // 已有设备重新上报：无论信号是否变化，都刷新 lastSeen；若曾置灰则恢复活跃
      final changed = ex.rssi != d.rssi;
      final revived = ex.stale;
      if (!changed && !revived) {
        // 无变化且本就活跃：仅刷新 lastSeen（表示本轮仍在持续上报）
        ex.lastSeen = DateTime.now();
        continue;
      }
      map[d.id] = ex.copyWith(
        rssi: d.rssi,
        seen: ex.seen + 1,
        stale: false,
        // 仅当新值有信息量时才覆盖（避免把 GATT 读到的型号冲掉）
        name: ex.name.isEmpty || ex.name == '(未知设备)' || ex.name.contains('未知')
            ? d.name
            : ex.name,
        brand: ex.brand == '未知' && d.brand != '未知' ? d.brand : ex.brand,
        category: ex.category.isEmpty && d.category.isNotEmpty ? d.category : ex.category,
        model: ex.model == null && d.model != null ? d.model : ex.model,
      );
      DeviceStore.upsert(map[d.id]!);
    }
  }

  /// 周期 housekeeping：无上报超阈值 → 置灰；置灰超阈值 → 删除（内存 + 数据库）。
  void _startHousekeeping() {
    _houseTimer?.cancel();
    _houseTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _housekeep());
  }

  void _housekeep() {
    if (!scanning) return;
    final now = DateTime.now();
    _sweep(_wifiMap, DeviceKind.wifi, now);
    _sweep(_bleMap, DeviceKind.ble, now);
    notify();
  }

  void _sweep(Map<String, Device> map, DeviceKind kind, DateTime now) {
    final ids = map.keys.toList();
    for (final id in ids) {
      final d = map[id]!;
      final idle = now.difference(d.lastSeen);
      if (d.stale) {
        // 已置灰，仍无上报超 removeAfter → 判定消失，删除
        if (idle >= _removeAfter) {
          map.remove(id);
          DeviceStore.remove(kind, id);
        }
      } else if (idle >= _staleAfter) {
        // 无上报超 staleAfter → 置灰并排至末尾（直接改字段，避免 copyWith 刷新 lastSeen）
        d.stale = true;
        DeviceStore.upsert(d);
      }
    }
  }

  /// 连续 WiFi 扫描：增量合并结果（不整体覆盖，避免扫描间隙数据消失）
  Future<void> _wifiLoop() async {
    while (scanning && detType == DeviceKind.wifi) {
      try {
        final w = WifiScanner();
        await w.start();
        await Future.delayed(const Duration(milliseconds: 600));
        if (!scanning || detType != DeviceKind.wifi) return;
        final fresh = await w.getResults();
        _mergeInto(_wifiMap, fresh);
        notify();
      } catch (_) {}
      await Future.delayed(
          sentinel ? const Duration(milliseconds: 400) : const Duration(milliseconds: 800));
    }
  }

  /// 连续 BLE 扫描（每次超时后自动续扫），通过订阅 scanResults 实时上报周边设备
  StreamSubscription? _bleSub;
  Future<void> _bleLoop() async {
    if (!scanning || detType != DeviceKind.ble) return;
    if (!(await _ble.supported)) return;
    _bleSub?.cancel();
    _bleSub = FlutterBluePlus.scanResults.listen((list) {
      if (!scanning || detType != DeviceKind.ble) return;
      final fresh = _ble.mapResults(list);
      _mergeInto(_bleMap, fresh);
      notify();
      // 收到广播后立即尝试解析型号/名称（抢 connectable 窗口，不等待定时器）
      _maybeResolveModels();
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

  /// 连续经典蓝牙 discovery：免配对发现可发现设备（耳机/手表/音箱/键鼠等），拿真实名 + CoD。
  Future<void> _classicLoop() async {
    while (scanning && detType == DeviceKind.ble) {
      try {
        await _classicBt.startDiscovery((r) {
          if (!scanning || detType != DeviceKind.ble) return;
          final d = _classicToDevice(r);
          _mergeInto(_bleMap, [d]);
          notify();
        });
        // discovery 持续一段时间后停止，让位给 BLE 扫描
        await Future.delayed(const Duration(seconds: 12));
        await _classicBt.stopDiscovery();
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// 经典蓝牙发现结果 → Device（radioType=classic）
  Device _classicToDevice(ClassicBtResult r) {
    final id = r.mac.toUpperCase();
    final res = classifyClassicBt(name: r.name, mac: id, cod: r.cod);
    final name = r.name.isNotEmpty
        ? r.name
        : (res.brand != '未知' && res.category.isNotEmpty
            ? '${res.brand} ${res.category}'
            : (res.brand != '未知' ? res.brand : '(未知设备)'));
    return Device(
      kind: DeviceKind.ble,
      id: id,
      name: name,
      brand: res.brand,
      domestic: res.domestic,
      rssi: r.rssi,
      category: res.category,
      radioType: RadioType.classic,
      model: res.model,
    );
  }

  void stopScan() {
    scanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    _houseTimer?.cancel();
    _houseTimer = null;
    _posTimer?.cancel();
    _posTimer = null;
    _beepTimer?.cancel();
    _beepTimer = null;
    _classicBt.stopDiscovery();
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
    // 定位期间保持扫描运行，实时获取目标 RSSI（不停止扫描，否则信号会冻结）
    if (!scanning) startScan();
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
    // 嘀嘀声：节奏随信号强度变化（越近越急促）
    _beepTimer?.cancel();
    _scheduleBeep();
  }

  void _posTick() {
    if (tracked == null) return;
    final list = tracked!.kind == DeviceKind.wifi ? wifi : ble;
    final live = list.where((x) => x.id == tracked!.id).isNotEmpty
        ? list.firstWhere((x) => x.id == tracked!.id)
        : null;
    // 直接采用实时 RSSI（目标持续发信号即实时刷新），随距离明显变化（近强远弱）
    final nr = live?.rssi ?? tracked!.rssi;
    tracked = tracked!.copyWith(rssi: nr, seen: tracked!.seen + 1);
    maxRssi = max(maxRssi, nr.toDouble());
    trend.add(nr);
    if (trend.length > 60) trend.removeAt(0);
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

  /// 嘀嘀声节奏：信号越强（越近）间隔越短 → 越急促；越弱（越远）间隔越长 → 越慢。
  int _beepIntervalMs(int rssi) {
    final t = ((rssi + 100) / 70).clamp(0.0, 1.0); // 0 远 .. 1 近
    return (1500 - 1300 * t).round(); // 1500ms(远) .. 200ms(近)
  }

  /// 自我重排的提示音定时器：节奏随当前信号强度变化（越近越急促）。
  void _scheduleBeep() {
    if (tracked == null || !scanning) {
      _beepTimer = null;
      return;
    }
    if (sound && !muted) _beep(1);
    final nr = tracked!.rssi;
    _beepTimer = Timer(Duration(milliseconds: _beepIntervalMs(nr)), _scheduleBeep);
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
      // 经典蓝牙设备已通过 remote name 拿到真实名，无 BLE 缓存，不做 GATT 解析
      if (d.radioType != RadioType.lowEnergy) continue;
      final nameUnknown =
          d.name.isEmpty || d.name.contains('未知设备') || d.name == '(未知设备)';
      final needs =
          d.model == null && (d.brand == 'Apple' || d.brand == '未知' || nameUnknown);
      if (!needs || _modelTried.contains(d.id)) continue;
      // 苹果/未知品牌（含 iOS 随机广播设备）即使广播 connectable=false 也尝试 GATT，
      // 以读取型号(0x2A24)/厂商名(0x2A29)/PnP(0x2A50) 等协议字段；其余品牌仅在可连接时尝试。
      if (d.brand != 'Apple' && !_ble.isConnectable(d.id)) continue;
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
              if (model.isNotEmpty) got = true;
            } else if (u.contains('2A00')) {
              devName = String.fromCharCodes(await c.read()).trim();
              if (devName.isNotEmpty) got = true;
            } else if (u.contains('2A29')) {
              mfr = String.fromCharCodes(await c.read()).trim();
            } else if (u.contains('2A01')) {
              final b = await c.read();
              if (b.length >= 2) appearance = b[0] | (b[1] << 8);
            } else if (u.contains('2A25')) {
              // Serial Number：设备唯一指纹（用于去重/报告列具体序列）
              serial = String.fromCharCodes(await c.read()).trim();
              if (serial.isNotEmpty) got = true;
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
    final cur = _bleMap[d.id];
    if (cur == null) return false;
    final pretty =
        (model != null && model.isNotEmpty) ? appleMarketingName(model) : null;
    // 仅当当前名称为兜底（未知/品牌品类拼接）时用 GATT 设备名覆盖
    final nameUnknown = cur.name.isEmpty ||
        cur.name == '(未知设备)' ||
        cur.name.contains('未知设备') ||
        (cur.name.contains(cur.brand) &&
            cur.category.isNotEmpty &&
            cur.name == '${cur.brand} ${cur.category}');
    final newName =
        (devName != null && devName.isNotEmpty && nameUnknown) ? devName : null;
    // 广播未给出品类时，用 0x2A01 外观补强
    String newCat = cur.category;
    if (newCat.isEmpty && appearance != null) {
      final ap = appearanceCategory(appearance);
      if (ap.isNotEmpty) newCat = ap;
    }
    // 厂商字段补强品牌（如 0x2A29=Apple）
    String newBrand = cur.brand;
    bool newDomestic = cur.domestic;
    if (newBrand == '未知' && mfr != null && mfr.toLowerCase().contains('apple')) {
      newBrand = 'Apple';
      newDomestic = false;
    }
    // PnP ID(0x2A50) 的 Vendor ID 是 SIG 公司码，与广播 Company ID 同空间 → 交叉验证品牌
    if (newBrand == '未知' && pnpVendorId != null) {
      final pb = brandFromCompanyId(pnpVendorId);
      if (pb != null && pb != '未知') {
        newBrand = pb;
        newDomestic = isDomesticBrand(pb);
      }
    }
    _bleMap[d.id] = cur.copyWith(
      model: pretty ?? cur.model,
      name: newName ?? cur.name,
      category: newCat,
      brand: newBrand,
      domestic: newDomestic,
      serial: serial ?? cur.serial,
    );
    DeviceStore.upsert(_bleMap[d.id]!);
    notify();
    return true;
  }

  void backToList() {
    stopPosition();
    overlay = 'detection';
    notify();
    if (!scanning) startScan();
  }

  void stopPosition() {
    _posTimer?.cancel();
    _posTimer = null;
    _beepTimer?.cancel();
    _beepTimer = null;
  }

  // ---------- 查扣 ----------
  void detain(Device d) {
    final map = detType == DeviceKind.wifi ? _wifiMap : _bleMap;
    final cur = map[d.id];
    if (cur != null) {
      map[d.id] = cur.copyWith(seized: true);
      DeviceStore.upsert(map[d.id]!);
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
    _beepTimer?.cancel();
    _bannerTimer?.cancel();
    _houseTimer?.cancel();
    _bleSub?.cancel();
    _classicBt.stopDiscovery();
    onChanged = null;
  }
}
