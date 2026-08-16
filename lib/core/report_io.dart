import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/report.dart';

/// 生成 CSV 文本（UTF-8 BOM，Excel 中文不乱码）
String buildCsv(Report r) {
  late List<String> header;
  late List<List<String>> rows;
  if (r.type == 'wifi') {
    header = ['名称', '品牌', '类型', '区域', '信号(dBm)', '距离(m)'];
    rows = r.devices.map((d) {
      d as Device;
      final type = d.wifiType == WifiType.direct
          ? 'WiFi Direct'
          : d.wifiType == WifiType.sta
              ? 'STA'
              : 'AP';
      return [
        d.name,
        d.brand,
        type,
        d.rssi >= r.indoorThr ? '室内' : '室外',
        d.rssi.toString(),
        d.distance.toStringAsFixed(1),
      ];
    }).toList();
  } else {
    header = ['名称', '品牌', '品类', '国产/进口', '区域', '信号(dBm)', '距离(m)'];
    rows = r.devices.map((d) {
      d as Device;
      return [
        d.name,
        d.brand,
        d.category.isEmpty ? '未知' : d.category,
        d.domestic ? '国产' : '进口',
        d.rssi >= r.indoorThr ? '室内' : '室外',
        d.rssi.toString(),
        d.distance.toStringAsFixed(1),
      ];
    }).toList();
  }
  final lines = [header.join(',')]
    ..addAll(rows.map((row) =>
        row.map((c) => '"${c.replaceAll('"', '""')}"').join(',')));
  return '\ufeff${lines.join('\n')}';
}

/// 写入外部存储（应用专属目录，无需额外权限），返回文件路径
Future<String> saveCsv(Report r) async {
  final dir = await getExternalStorageDirectory();
  final safe = r.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${dir!.path}/$safe.csv');
  await file.writeAsString(buildCsv(r), encoding: utf8);
  return file.path;
}
