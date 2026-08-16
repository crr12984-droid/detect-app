import 'package:flutter/material.dart';

/// 原型配色（ui_prototype.html :root 变量）
class AppColors {
  static const bg = Color(0xFF0F1419);
  static const panel = Color(0xFF171E27);
  static const panel2 = Color(0xFF1D2632);
  static const line = Color(0xFF2A3340);
  static const txt = Color(0xFFE7ECF2);
  static const txt2 = Color(0xFF8B95A4);
  static const txt3 = Color(0xFF5E6977);
  static const acc = Color(0xFF3B82F6);
  static const acc2 = Color(0xFF22B8CF);
  static const ok = Color(0xFF2E9E5B);
  static const warn = Color(0xFFD9A441);
  static const bad = Color(0xFFEF4444);
  static const radius = 14.0;
}

ThemeData buildAppTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.acc,
      useMaterial3: true,
      cardColor: AppColors.panel,
      dividerColor: AppColors.line,
      fontFamily: '-apple-system, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif',
      colorScheme: ColorScheme.dark(
        primary: AppColors.acc,
        secondary: AppColors.acc2,
        surface: AppColors.panel,
        background: AppColors.bg,
      ),
    );
