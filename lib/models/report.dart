class Report {
  final int id;
  final String name;
  final String label;
  final String type; // 'wifi' | 'ble'
  final String time;
  final int count;
  final List<dynamic> devices; // List<Device>
  final double indoorThr;
  final String remark;

  Report({
    required this.id,
    required this.name,
    required this.label,
    required this.type,
    required this.time,
    required this.count,
    required this.devices,
    this.indoorThr = 2.0,
    this.remark = '',
  });
}
