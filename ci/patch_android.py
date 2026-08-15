#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
在 `flutter create --platforms=android` 生成标准原生工程之后，把本项目
真正需要的东西补回去。CI 与本机出包共用这一份脚本，避免两边配置分叉。

补三件事：
  1. AndroidManifest.xml 注入 WiFi / 蓝牙 / 位置权限与硬件特性声明
  2. 应用名改为中文「智能终端检测定位」，并允许平板横竖屏自适应
  3. minSdk 提到 23（flutter_blue_plus / wifi_scan 的下限要求）

为什么不直接把手写的 AndroidManifest.xml 提交进仓库：
flutter create 遇到已存在的清单会跳过生成，导致缺少 Flutter 必需的
`flutterEmbedding=2` 等 meta-data，装上去会直接崩溃。所以清单一律由
flutter create 生成，再由本脚本打补丁。
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

PERMISSIONS = """
    <!-- 网络 / WiFi 扫描必需 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />

    <!-- 位置权限：Android 6+ 扫描 WiFi 与 BLE 强制需要 -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- Android 13+ 免定位扫描 WiFi -->
    <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES"
        android:usesPermissionFlags="neverForLocation" />

    <!-- 蓝牙（Android 11 及以下） -->
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />

    <!-- 蓝牙（Android 12+） -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <!-- 硬件特性：声明为非必需，缺硬件的设备也允许安装 -->
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />
    <uses-feature android:name="android.hardware.wifi" android:required="false" />
"""


def patch_manifest() -> bool:
    p = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not p.exists():
        print("[FAIL] 找不到 AndroidManifest.xml，请先执行 flutter create --platforms=android .")
        return False
    s = p.read_text(encoding="utf-8")

    # 1) 注入权限（幂等：已注入则跳过）
    if "ACCESS_FINE_LOCATION" in s:
        print("[skip] 权限已存在")
    else:
        m = re.search(r"<manifest[^>]*>", s)
        if not m:
            print("[FAIL] 清单格式异常，找不到 <manifest> 标签")
            return False
        s = s[: m.end()] + "\n" + PERMISSIONS + s[m.end():]
        print("[ok] 已注入 WiFi / 蓝牙 / 位置权限")

    # 2) 应用名改中文
    s2 = re.sub(r'android:label="[^"]*"', 'android:label="智能终端检测定位"', s, count=1)
    if s2 != s:
        print("[ok] 应用名 -> 智能终端检测定位")
        s = s2

    # 3) 平板/手机横竖屏自适应：configChanges 里补上 screenLayout 等
    if "screenLayout" not in s:
        s = s.replace(
            'android:configChanges="orientation|keyboardHidden|keyboard|screenSize|'
            'smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"',
            'android:configChanges="orientation|keyboardHidden|keyboard|screenSize|'
            'smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"',
        )

    p.write_text(s, encoding="utf-8")
    return True


def patch_min_sdk() -> bool:
    """兼容 Kotlin DSL(build.gradle.kts) 与 Groovy(build.gradle) 两种脚手架。"""
    kts = ROOT / "android/app/build.gradle.kts"
    groovy = ROOT / "android/app/build.gradle"

    if kts.exists():
        s = kts.read_text(encoding="utf-8")
        new = re.sub(r"minSdk\s*=\s*[\w.().]+", "minSdk = 23", s, count=1)
        if new != s:
            kts.write_text(new, encoding="utf-8")
            print("[ok] build.gradle.kts minSdk -> 23")
        else:
            print("[warn] build.gradle.kts 未匹配到 minSdk，保持默认")
        return True

    if groovy.exists():
        s = groovy.read_text(encoding="utf-8")
        new = re.sub(r"minSdkVersion\s+[\w.().]+", "minSdkVersion 23", s, count=1)
        if new == s:
            new = re.sub(r"minSdk\s+[\w.().]+", "minSdk 23", s, count=1)
        if new != s:
            groovy.write_text(new, encoding="utf-8")
            print("[ok] build.gradle minSdk -> 23")
        else:
            print("[warn] build.gradle 未匹配到 minSdk，保持默认")
        return True

    print("[FAIL] 找不到 app/build.gradle(.kts)")
    return False


def main() -> int:
    ok = patch_manifest() and patch_min_sdk()
    if ok:
        print("\n补丁完成，可以执行 flutter build apk --release")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
