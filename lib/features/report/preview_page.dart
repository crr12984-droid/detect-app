import 'package:flutter/material.dart';
import '../../app/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui_assets.dart';
import '../../core/report_io.dart';
import '../../models/device.dart';
import '../../models/report.dart';
import '../common/widgets.dart';

/// 报告预览（全屏）：PDF 样式白底文档（元信息 + 设备明细表 + U盘导出）。
class PreviewPage extends StatelessWidget {
  final AppState state;
  const PreviewPage(this.state);

  @override
  Widget build(BuildContext context) {
    final r = state.previewReport;
    if (r == null) {
      return const Center(child: Text('无预览报告', style: TextStyle(color: AppColors.txt3)));
    }
    final isWifi = r.type == 'wifi';
    final devices = r.devices.whereType<Device>().toList();
    final thr = r.indoorThr;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          _iconBtn('arrow-left', state.backFromPreview),
          const SizedBox(width: 12),
          Expanded(
            child: Text(r.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          _expBtn(context, r),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 760),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8))
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('智能终端检测报告',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2A4A), height: 1.2),
                      textAlign: TextAlign.center),
                  const Text('保密 · 仅限授权人员查阅',
                      style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 24,
                    runSpacing: 10,
                    children: [
                      _meta('报告类型', r.label),
                      _meta('生成时间', r.time),
                      _meta('设备总数', '${devices.length} 台'),
                      _meta('判定阈值', '$thr dBm'),
                      _meta('巡检员', '管理员'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _table(isWifi, devices, thr),
                  const SizedBox(height: 22),
                  const Text('本报告由智能终端检测定位系统自动生成，数据来源于现场实时扫描。',
                      style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _meta(String k, String v) => SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(fontSize: 11.5, color: Color(0xFF888888))),
            const SizedBox(height: 3),
            Text(v,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      );

  Widget _table(bool isWifi, List<Device> devices, int thr) {
    final headers = isWifi
        ? ['序号', '名称', '品牌', '类型', '信号(dBm)', '距离(m)', '区域']
        : ['序号', '名称', '品牌', '品类', '国产/进口', '信号(dBm)', '距离(m)', '区域'];
    return Table(
      border: TableBorder.all(color: const Color(0xFFC9D2DC), width: 1),
      columnWidths: const {},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFEEF3F8)),
          children: headers
              .map((h) => _c(h, bold: true))
              .toList(),
        ),
        ...devices.asMap().entries.map((e) {
          final d = e.value;
          final i = e.key + 1;
          final rows = isWifi
              ? [
                  '$i',
                  d.name,
                  brandLabel(d.brand),
                  d.wifiType == WifiType.direct
                      ? 'WiFi Direct'
                      : d.wifiType == WifiType.sta
                          ? 'STA'
                          : 'AP',
                  '${d.rssi}',
                  d.distance.toStringAsFixed(1),
                  d.rssi >= thr ? '室内' : '室外',
                ]
              : [
                  '$i',
                  d.name,
                  brandLabel(d.brand),
                  d.category.isEmpty ? '未知' : d.category,
                  d.domestic ? '国产' : '进口',
                  '${d.rssi}',
                  d.distance.toStringAsFixed(1),
                  d.rssi >= thr ? '室内' : '室外',
                ];
          return TableRow(
              children: rows.map((t) => _c(t, small: true)).toList());
        }),
      ],
    );
  }

  Widget _c(String t, {bool bold = false, bool small = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(t,
            style: TextStyle(
                fontSize: small ? 12 : 12.5,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: Colors.black87)),
      );

  Widget _iconBtn(String icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.panel2,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: AppIcon(icon, size: 20)),
        ),
      );

  Widget _expBtn(BuildContext ctx, Report r) => InkWell(
        onTap: () async {
          final p = await saveCsv(r);
          state.showBanner('已通过设备U盘导出：${p.split('/').last}');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.acc, const Color(0xFF2F6FE0)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            AppIcon('usb', size: 16, color: Colors.white),
            const SizedBox(width: 7),
            const Text('导出',
                style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
