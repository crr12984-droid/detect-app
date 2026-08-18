import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/device.dart';

/// 设备列表的本地持久化存储（SQLite）。
/// 需求：首次扫描展示全部设备并入库；信号/距离变化则更新；新增则追加；
/// 超时未上报 → 置灰排末尾；置灰超时 → 删除。
/// 本类只负责「落盘」，实时合并/置灰/删除的调度在 AppState。
/// 设备以完整 JSON 落盘，避免字段丢失（wifiType/channel/txPower 等）。
class DeviceStore {
  static Database? _db;

  static Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      '$dir/detect_devices.db',
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE devices (
            kind TEXT NOT NULL,
            id TEXT NOT NULL,
            json TEXT NOT NULL,
            last_seen INTEGER,
            stale INTEGER,
            PRIMARY KEY (kind, id)
          )
        ''');
      },
    );
    return _db!;
  }

  /// 全部设备（wifi / ble 分类读取）
  static Future<List<Device>> loadAll(DeviceKind kind) async {
    try {
      final db = await _database;
      final rows = await db.query('devices',
          where: 'kind = ?', whereArgs: [kind.name]);
      return rows
          .map((r) => Device.fromJson(jsonDecode(r['json'] as String) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 插入或更新单条设备
  static Future<void> upsert(Device d) async {
    try {
      final db = await _database;
      await db.insert(
          'devices',
          {
            'kind': d.kind.name,
            'id': d.id,
            'json': jsonEncode(d.toJson()),
            'last_seen': d.lastSeen.millisecondsSinceEpoch,
            'stale': d.stale ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  /// 批量插入/更新
  static Future<void> upsertAll(List<Device> list) async {
    try {
      final db = await _database;
      final batch = db.batch();
      for (final d in list) {
        batch.insert(
            'devices',
            {
              'kind': d.kind.name,
              'id': d.id,
              'json': jsonEncode(d.toJson()),
              'last_seen': d.lastSeen.millisecondsSinceEpoch,
              'stale': d.stale ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  /// 删除单条设备（判定消失后）
  static Future<void> remove(DeviceKind kind, String id) async {
    try {
      final db = await _database;
      await db.delete('devices',
          where: 'kind = ? AND id = ?', whereArgs: [kind.name, id]);
    } catch (_) {}
  }

  /// 清空某类设备（退出检测时可选）
  static Future<void> clear(DeviceKind kind) async {
    try {
      final db = await _database;
      await db.delete('devices', where: 'kind = ?', whereArgs: [kind.name]);
    } catch (_) {}
  }

  // 供调试/导出用：把整库 dump 成 JSON 字符串（不参与主流程）
  static Future<String> dumpJson() async {
    try {
      final db = await _database;
      final rows = await db.query('devices');
      return jsonEncode(rows);
    } catch (_) {
      return '[]';
    }
  }
}
