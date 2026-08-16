import 'package:flutter/material.dart';
import '../../app/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui_assets.dart';
import '../../core/report_io.dart';
import '../../models/device.dart';
import '../../models/report.dart';
import '../common/widgets.dart';

/// 报告预览（全屏）：元信息 + 设备明细表 + U盘导出（写入外部存储）。
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 元信息
            Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 28,
                runSpacing: 14,
                children: [
                  _meta('检测类型', r.label),
                  _meta('生成时间', r.time),
                  _meta('设备数量', '${r.count} 台'),
                  if (r.remark.isNotEmpty) _meta('备注', r.remark),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _header(isWifi),
                  ...devices.map((d) => _row(d, isWifi, context)).toList(),
                ],
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _meta(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 11.5, color: AppColors.txt3)),
          const SizedBox(height: 3),
          Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _header(bool isWifi) {
    final labels = isWifi
        ? ['名称', '品牌', '区域', '信号', '距离']
        : ['名称', '品牌', '品类', '区域', '信号', '距离'];
    final flex = isWifi ? [4, 3, 2, 2, 2] : [4, 3, 2, 2, 2, 2];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: List.generate(labels.length,
            (i) => Expanded(flex: flex[i], child: Text(labels[i],
                style: const TextStyle(fontSize: 12, color: AppColors.txt3)))),
      ),
    );
  }

  Widget _row(Device d, bool isWifi, BuildContext ctx) {
    final indoor = d.distance >= (state.previewReport?.indoorThr ?? 2.0);
    final nameCell = Row(children: [
      CatIcon(d.category.isEmpty ? '路由器' : d.category),
      const SizedBox(width: 9),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          Text(d.id, style: const TextStyle(fontSize: 11, color: AppColors.txt2,
              fontFamily: 'monospace')),
        ]),
      ),
    ]);
    final brandCell = Row(children: [
      BrandLogo(d.brand, size: 14),
      const SizedBox(width: 7),
      Expanded(child: Text(d.brand, style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis)),
    ]);
    final catCell = d.category.isEmpty
        ? const Text('未知', style: TextStyle(fontSize: 12, color: AppColors.txt3))
        : Row(children: [
            CatIcon(d.category, size: 14),
            const SizedBox(width: 6),
            Text(d.category, style: const TextStyle(fontSize: 12)),
          ]);

    final cells = isWifi
        ? [nameCell, brandCell, ZoneTag(indoor), SignalBars4(d.rssi),
            Text('${d.distance.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 12))]
        : [nameCell, brandCell, catCell, ZoneTag(indoor), SignalBars4(d.rssi),
            Text('${d.distance.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 12))];

    final flex = isWifi ? [4, 3, 2, 2, 2] : [4, 3, 2, 2, 2, 2];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1B232E)))),
      child: Row(
        children: List.generate(cells.length,
            (i) => Expanded(flex: flex[i], child: cells[i])),
      ),
    );
  }

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
          toast(ctx, '已通过设备U盘导出：${p.split('/').last}');
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
            const Text('U盘导出',
                style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
