import 'package:flutter/material.dart';
import '../../app/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui_assets.dart';
import '../../core/report_io.dart';
import '../../models/report.dart';
import '../common/widgets.dart';

/// 报告管理：列表 + 选择(批量删除) + 单条删除 + 点按预览 + CSV 导出。
class ReportPage extends StatelessWidget {
  final AppState state;
  const ReportPage(this.state);

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            const SecHead('报告管理'),
            const Spacer(),
            if (state.selMode) ...[
              InkWell(
                onTap: state.toggleSelAll,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                      child: Text('全选', style: TextStyle(fontSize: 13, color: AppColors.txt2))),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  if (state.selReports.isEmpty) {
                    toast(context, '请先勾选要删除的报告');
                    return;
                  }
                  _confirm(context, '批量删除',
                      '确定删除选中的 ${state.selReports.length} 个报告？此操作不可恢复。',
                      () => state.batchDelete());
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bad.withOpacity(0.13),
                    border: Border.all(color: AppColors.bad.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                      child: Text('批量删除',
                          style: TextStyle(fontSize: 13, color: AppColors.bad))),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: state.toggleSelMode,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                      child: Text('取消', style: TextStyle(fontSize: 13, color: AppColors.txt2))),
                ),
              ),
            ] else ...[
              InkWell(
                onTap: state.toggleSelMode,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    AppIcon('list', size: 15, color: AppColors.txt2),
                    const SizedBox(width: 6),
                    const Text('管理', style: TextStyle(fontSize: 13, color: AppColors.txt2)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          child: state.reports.isEmpty
              ? const Center(
                  child: Text('暂无报告，请先在「智能检测」中执行扫描并导出',
                      style: TextStyle(color: AppColors.txt3)))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: state.reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _item(state.reports[i], context),
                ),
        ),
      ]);

  Widget _item(Report r, BuildContext ctx) {
    final selected = state.selReports.contains(r.id);
    final isWifi = r.type == 'wifi';
    return InkWell(
      onTap: state.selMode
          ? () => state.toggleSel(r.id)
          : () => state.openPreview(r),
      onLongPress: () {
        if (!state.selMode) {
          state.toggleSelMode();
          state.toggleSel(r.id);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.acc.withOpacity(0.08) : AppColors.panel,
          border: Border.all(
              color: selected ? AppColors.acc : AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          if (state.selMode)
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.acc : Colors.transparent,
                border: Border.all(
                    color: selected ? AppColors.acc : AppColors.txt3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            )
          else
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: (isWifi ? AppColors.acc : const Color(0xFF8B5CF6))
                    .withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: AppIcon(isWifi ? 'wifi' : 'bluetooth',
                      size: 22,
                      color: isWifi ? AppColors.acc : const Color(0xFF8B5CF6))),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${r.time} · ${r.count} 台设备',
                    style: const TextStyle(fontSize: 12, color: AppColors.txt2)),
              ],
            ),
          ),
          if (!state.selMode) ...[
            _mini(ctx, 'usb', '导出', () async {
              final p = await saveCsv(r);
              toast(ctx, '已导出：${p.split('/').last}');
            }),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _confirm(ctx, '删除报告',
                  '确定删除该报告？此操作不可恢复。', () => state.deleteReport(r.id)),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.bad.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                    child: AppIcon('trash-2', size: 16, color: AppColors.bad)),
              ),
            ),
            const SizedBox(width: 8),
            AppIcon('chevron-right', size: 18, color: AppColors.txt3),
          ],
        ]),
      ),
    );
  }

  Widget _mini(BuildContext ctx, String icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            AppIcon(icon, size: 15, color: AppColors.txt2),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.txt2)),
          ]),
        ),
      );

  void _confirm(BuildContext ctx, String title, String body, VoidCallback ok) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(title, style: const TextStyle(color: AppColors.txt)),
        content: Text(body, style: const TextStyle(color: AppColors.txt2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppColors.txt2)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ok();
            },
            child: const Text('确定', style: TextStyle(color: AppColors.bad)),
          ),
        ],
      ),
    );
  }
}
