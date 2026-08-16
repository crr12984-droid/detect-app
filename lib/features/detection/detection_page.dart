import 'package:flutter/material.dart';
import '../../app/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui_assets.dart';
import '../../models/device.dart';
import '../common/widgets.dart';

class DetectionPage extends StatelessWidget {
  final AppState state;
  const DetectionPage(this.state);

  @override
  Widget build(BuildContext context) {
    final isWifi = state.detType == DeviceKind.wifi;
    final title = isWifi ? 'WiFi检测' : '国外设备检测';
    final list = state.filteredList;
    final indoor = list.where((d) => state.isIndoor(d)).toList();
    final outdoor = list.where((d) => !state.isIndoor(d)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          _iconBtn('arrow-left', state.backToApp),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600))),
          _textBtn(context, '报告导出', 'download',
              () => {state.exportReport(), toast(context, '导出成功')}),
          const SizedBox(width: 8),
          _scanBtn(),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(children: [
            Row(children: [
              _statPill(true, indoor.length),
              const SizedBox(width: 12),
              _statPill(false, outdoor.length),
            ]),
            if (!isWifi) _chips(),
            const SizedBox(height: 8),
            if (indoor.isNotEmpty)
              _group(true, '室内', indoor, isWifi, context),
            if (outdoor.isNotEmpty)
              _group(false, '室外', outdoor, isWifi, context),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Text('未发现设备，请确认已开启定位与蓝牙后重新扫描',
                    style: TextStyle(color: AppColors.txt3)),
              ),
          ]),
        ),
      ),
    ]);
  }

  // ---------- 头部控件 ----------
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

  Widget _textBtn(BuildContext ctx, String label, String icon,
          VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            AppIcon(icon, size: 16, color: AppColors.txt2),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.txt2, fontWeight: FontWeight.w500)),
          ]),
        ),
      );

  Widget _scanBtn() => InkWell(
        onTap: state.toggleScan,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: state.scanning
                ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                : [AppColors.acc, const Color(0xFF2F6FE0)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            AppIcon(state.scanning ? 'pause' : 'play', size: 16, color: Colors.white),
            const SizedBox(width: 7),
            Text(state.scanning ? '暂停' : '继续扫描',
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ---------- 统计 / 筛选 ----------
  Widget _statPill(bool indoor, int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: indoor
              ? AppColors.acc.withOpacity(0.13)
              : AppColors.ok.withOpacity(0.13),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(children: [
          AppIcon(indoor ? 'house' : 'sun', size: 16,
              color: indoor
                  ? const Color(0xFF8FB6FF)
                  : const Color(0xFF5FCA86)),
          const SizedBox(width: 8),
          Text(indoor ? '室内' : '室外',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: indoor
                      ? const Color(0xFF8FB6FF)
                      : const Color(0xFF5FCA86))),
          const SizedBox(width: 6),
          Text('$n',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: indoor
                      ? const Color(0xFF8FB6FF)
                      : const Color(0xFF5FCA86))),
        ]),
      );

  Widget _chips() {
    final filters = [
      ['all', '所有品牌设备'],
      ['foreign', '国外品牌设备'],
      ['apple', '苹果设备'],
      ['seized', '已查扣设备'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 8,
        children: filters
            .map((f) => InkWell(
                  onTap: () => state.setBtFilter(f[0]),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: state.btFilter == f[0]
                          ? AppColors.acc
                          : AppColors.panel2,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(f[1],
                        style: TextStyle(
                            fontSize: 12.5,
                            color: state.btFilter == f[0]
                                ? Colors.white
                                : AppColors.txt2,
                            fontWeight: state.btFilter == f[0]
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ---------- 分组表 ----------
  Widget _group(bool indoor, String title, List<Device> items, bool isWifi,
      BuildContext ctx) {
    final flex = isWifi
        ? [4, 3, 2, 3, 2, 2]
        : [4, 3, 2, 2, 3, 2, 2];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          AppIcon(indoor ? 'house' : 'sun', size: 16,
              color: indoor ? const Color(0xFF8FB6FF) : const Color(0xFF5FCA86)),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: indoor
                      ? const Color(0xFF8FB6FF)
                      : const Color(0xFF5FCA86))),
          const SizedBox(width: 8),
          Text('${items.length} 台',
              style: const TextStyle(fontSize: 12.5, color: AppColors.txt3)),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          _header(flex, isWifi),
          ...items.map((d) => _row(flex, d, isWifi, ctx)).toList(),
        ]),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _header(List<int> flex, bool isWifi) {
    final labels = isWifi
        ? ['名称', '品牌', '区域', '信号', '距离', '']
        : ['名称', '品牌', '品类', '区域', '信号', '距离', ''];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: List.generate(labels.length,
            (i) => Expanded(flex: flex[i], child: Text(labels[i],
                style: const TextStyle(fontSize: 12, color: AppColors.txt3)))),
      ),
    );
  }

  Widget _row(List<int> flex, Device d, bool isWifi, BuildContext ctx) {
    final indoor = state.isIndoor(d);
    final nameCell = Row(children: [
      CatIcon(d.category.isEmpty ? '路由器' : d.category),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.name,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            Text(d.id,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.txt2, fontFamily: 'monospace')),
          ],
        ),
      ),
    ]);
    final brandCell = Row(children: [
      BrandLogo(d.brand, size: 14),
      const SizedBox(width: 7),
      Expanded(
        child: Row(children: [
          Text(d.brand,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
          if (!isWifi) ...[
            const SizedBox(width: 6),
            DomesticTag(d.domestic),
          ],
        ]),
      ),
    ]);
    final catCell = d.category.isEmpty
        ? const Text('未知', style: TextStyle(fontSize: 12, color: AppColors.txt3))
        : Row(children: [
            CatIcon(d.category, size: 14),
            const SizedBox(width: 6),
            Text(d.category, style: const TextStyle(fontSize: 12)),
          ]);
    final signalCell = Row(children: [
      SignalBars4(d.rssi),
      const SizedBox(width: 6),
      Text('${d.rssi}',
          style: const TextStyle(fontSize: 12, color: AppColors.txt2)),
    ]);
    final distCell =
        Text('${d.distance.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 12));
    final opCell = Row(children: [
      _opBtn('定位', 'crosshair', const Color(0xFF7EB0FF),
          () => state.openPosition(d)),
      const SizedBox(width: 6),
      if (d.seized)
        const Text('已查扣',
            style: TextStyle(fontSize: 12, color: AppColors.bad, fontWeight: FontWeight.w600))
      else
        _opBtn('查扣', 'gavel', const Color(0xFFF08A8A), () {
          state.detain(d);
          toast(ctx, '已查扣：${d.name}');
        }),
    ]);

    final cells = isWifi
        ? [nameCell, brandCell, ZoneTag(indoor), signalCell, distCell, opCell]
        : [nameCell, brandCell, catCell, ZoneTag(indoor), signalCell, distCell, opCell];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1B232E)))),
      child: Row(
        children: List.generate(cells.length,
            (i) => Expanded(flex: flex[i], child: cells[i])),
      ),
    );
  }

  Widget _opBtn(String label, String icon, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            AppIcon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ]),
        ),
      );
}
