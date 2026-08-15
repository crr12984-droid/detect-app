import 'package:flutter/material.dart';
import 'features/detection/detection_page.dart';

void main() {
  runApp(const DetectApp());
}

class DetectApp extends StatelessWidget {
  const DetectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能终端检测定位',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF22B8CF),
        scaffoldBackgroundColor: const Color(0xFF0A0F14),
        useMaterial3: true,
        cardColor: const Color(0xFF121A22),
        dividerColor: const Color(0xFF1E2A36),
      ),
      home: const DetectionPage(),
    );
  }
}
