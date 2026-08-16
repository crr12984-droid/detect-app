import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

/// 申请扫描所需的运行时权限。
/// 返回 true 表示位置权限已授予（Android 6+ 扫描 WiFi / BLE 的必要条件）。
Future<bool> ensureScanPermissions() async {
  // Android 12+ 蓝牙扫描 / 连接权限
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
  // 位置权限：Android 11- 扫描 WiFi 与 BLE 强制需要；12+ 用于兼容各厂商实现
  final loc = await Permission.locationWhenInUse.request();
  return loc.isGranted;
}

/// 系统“定位服务 / GPS”是否已开启。
/// 安卓 11 及以下：关闭时 WiFi / 蓝牙扫描必然返回空；12+ 部分机型同样受限。
Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();
