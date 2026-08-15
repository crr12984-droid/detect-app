import 'dart:math';

/// 由 RSSI 估算到信号源的距离（米）。
/// measuredAt1m: 距发射端 1 米处的参考 RSSI（常见路由器约 -50~-55）
/// pathLoss: 路径损耗指数，室内约 2.7~3.5
double rssiToDistance(int rssi, {int measuredAt1m = -50, double pathLoss = 3.0}) {
  if (rssi >= measuredAt1m) return 0.5;
  final diff = measuredAt1m - rssi;
  return pow(10, diff / (10 * pathLoss)).toDouble();
}

/// 将 RSSI 映射到 0~8 格信号强度（与现有原型 8 格逻辑一致）
int rssiToBars(int rssi) {
  if (rssi >= -40) return 8;
  if (rssi >= -47) return 7;
  if (rssi >= -54) return 6;
  if (rssi >= -61) return 5;
  if (rssi >= -68) return 4;
  if (rssi >= -75) return 3;
  if (rssi >= -82) return 2;
  if (rssi >= -89) return 1;
  return 0;
}
