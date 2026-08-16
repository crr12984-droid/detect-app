import 'package:flutter/material.dart';
import '../../app/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui_assets.dart';
import '../common/widgets.dart';
import '../../models/device.dart';

class SmartPage extends StatelessWidget {
  final AppState state;
  const SmartPage(this.state);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecHead('智能检测'),
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: 1.5,
                children: [
                  _Tile(
                    icon: 'wifi',
                    title: 'WiFi检测',
                    c1: const Color(0xFF3B82F6),
                    c2: const Color(0xFF2563EB),
                    onTap: () => state.openDetection(DeviceKind.wifi),
                  ),
                  _Tile(
                    icon: 'bluetooth',
                    title: '国外设备检测',
                    c1: const Color(0xFF8B5CF6),
                    c2: const Color(0xFF6D28D9),
                    onTap: () => state.openDetection(DeviceKind.ble),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
}

class _Tile extends StatelessWidget {
  final String icon;
  final String title;
  final Color c1;
  final Color c2;
  final VoidCallback onTap;
  const _Tile(
      {required this.icon,
      required this.title,
      required this.c1,
      required this.c2,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c1, c2]),
                  borderRadius: BorderRadius.circular(22)),
              child: Center(child: AppIcon(icon, size: 46, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
