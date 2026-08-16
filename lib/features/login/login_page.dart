import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/ui_assets.dart';

/// 登录界面：账号 admin / 密码 chenjian。
class LoginPage extends StatefulWidget {
  final VoidCallback onSuccess;
  const LoginPage({super.key, required this.onSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _acc = TextEditingController(text: 'admin');
  final _pwd = TextEditingController(text: 'chenjian');
  String? _err;

  void _submit() {
    final a = _acc.text.trim();
    final p = _pwd.text;
    if (a == 'admin' && p == 'chenjian') {
      widget.onSuccess();
    } else {
      setState(() => _err = '账号或密码错误（应为 admin / chenjian）');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [Color(0xFF152230), Color(0xFF0A0E14)],
            ),
          ),
          child: Center(
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF22B8CF)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Text('检',
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(height: 18),
                const Text('智能终端检测定位系统',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('登录以进入检测控制台',
                    style: TextStyle(fontSize: 13, color: AppColors.txt2)),
                const SizedBox(height: 24),
                _field(_acc, '账号', false),
                const SizedBox(height: 12),
                _field(_pwd, '密码', true),
                const SizedBox(height: 8),
                if (_err != null)
                  Text(_err!,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.bad)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.acc,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('登 录'),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('默认账号 admin / 密码 chenjian',
                    style: TextStyle(fontSize: 12, color: AppColors.txt3)),
              ]),
            ),
          ),
        ),
      );

  Widget _field(TextEditingController c, String hint, bool pwd) => TextField(
        controller: c,
        obscureText: pwd,
        style: const TextStyle(color: AppColors.txt),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.txt3),
          filled: true,
          fillColor: AppColors.panel2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.acc),
          ),
        ),
      );
}
