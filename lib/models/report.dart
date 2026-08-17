import 'device.dart';

class Report {
  final int id;
  final String name;
  final String label;
  final String type; // 'wifi' | 'ble'
  final String time;
  final int count;
  final List<dynamic> devices; // List<Device>
  final int indoorThr; // 室内判定阈值（dBm）
  final String remark;

  Report({
    required this.id,
    required this.name,
    required this.label,
    required this.type,
    required this.time,
    required this.count,
    required this.devices,
    this.indoorThr = -60,
    this.remark = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'label': label,
        'type': type,
        'time': time,
        'count': count,
        'devices': devices.map((d) => (d as Device).toJson()).toList(),
        'indoorThr': indoorThr,
        'remark': remark,
      };

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        id: j['id'] as int,
        name: j['name'] as String,
        label: j['label'] as String,
        type: j['type'] as String,
        time: j['time'] as String,
        count: j['count'] as int,
        devices: (j['devices'] as List)
            .map((d) => Device.fromJson(d as Map<String, dynamic>))
            .toList(),
        indoorThr: (j['indoorThr'] as int?) ?? -60,
        remark: (j['remark'] as String?) ?? '',
      );
}
