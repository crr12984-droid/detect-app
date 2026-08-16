import 'package:flutter/material.dart';
import 'app/app_state.dart';
import 'app/app_shell.dart';
import 'core/theme.dart';

void main() => runApp(const DetectApp());

/// 应用根：持有全局 AppState，onChanged 触发重建（无需登录，直达主界面）。
class DetectApp extends StatefulWidget {
  const DetectApp({super.key});
  @override
  State<DetectApp> createState() => _DetectAppState();
}

class _DetectAppState extends State<DetectApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
    _state.onChanged = () => setState(() {});
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '智能终端检测定位',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: AppShell(state: _state),
      );
}
