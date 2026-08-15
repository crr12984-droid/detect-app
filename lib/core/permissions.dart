import 'package:permission_handler/permission_handler.dart';

/// 申请扫描所需的运行时权限。
/// 返回 true 表示位置权限已授予（Android 6+ 扫描 WiFi / BLE 的必要条件）。
Future<bool> ensureScanPermissions() async {
  final loc = await Permission.locationWhenInUse.request();
  // Android 12+ 蓝牙扫描 / 连接权限
  if (await Permission.bluetoothScan.isDenied) {
    await Permission.bluetoothScan.request();
  }
  if (await Permission.bluetoothConnect.isDenied) {
    await Permission.bluetoothConnect.request();
  }
  return loc.isGranted;
}
