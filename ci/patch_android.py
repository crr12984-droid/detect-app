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

    <!-- Android 13+ 扫描 WiFi（不声明 neverForLocation，避免部分机型 startScan 返回未授权） -->
    <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />

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

    # 3) 自检：清单必须由 flutter create 生成，缺 flutterEmbedding v2 会直接崩溃
    if "flutterEmbedding" not in s:
        print("[FAIL] 清单缺少 flutterEmbedding，说明它不是 flutter create 生成的。")
        print("       请先删除 android/ 目录再执行 flutter create --platforms=android .")
        return False

    p.write_text(s, encoding="utf-8")
    return True


def patch_min_sdk() -> bool:
    """兼容 Kotlin DSL(build.gradle.kts) 与 Groovy(build.gradle) 两种脚手架。"""
    kts = ROOT / "android/app/build.gradle.kts"
    groovy = ROOT / "android/app/build.gradle"

    if kts.exists():
        s = kts.read_text(encoding="utf-8")
        if re.search(r"minSdk\s*=\s*23\b", s):
            print("[skip] build.gradle.kts minSdk 已是 23")
            return True
        new = re.sub(r"minSdk\s*=\s*[\w.().]+", "minSdk = 23", s, count=1)
        if new != s:
            kts.write_text(new, encoding="utf-8")
            print("[ok] build.gradle.kts minSdk -> 23")
        else:
            print("[warn] build.gradle.kts 未匹配到 minSdk，保持默认")
        return True

    if groovy.exists():
        s = groovy.read_text(encoding="utf-8")
        if re.search(r"minSdk(Version)?\s+23\b", s):
            print("[skip] build.gradle minSdk 已是 23")
            return True
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


def patch_compile_sdk() -> bool:
    """把 compileSdk 提到 36：flutter_blue_plus_android / geolocator_android 等插件
    要求 compileSdk >= 36（向后兼容），否则 :checkReleaseAarMetadata 会失败。
    兼容 Kotlin DSL 与 Groovy 两种脚手架。"""
    kts = ROOT / "android/app/build.gradle.kts"
    groovy = ROOT / "android/app/build.gradle"

    if kts.exists():
        s = kts.read_text(encoding="utf-8")
        if re.search(r"compileSdk\s*=\s*36\b", s):
            print("[skip] build.gradle.kts compileSdk 已是 36")
            return True
        new = re.sub(r"compileSdk\s*=\s*flutter\.compileSdkVersion",
                     "compileSdk = 36", s, count=1)
        if new != s:
            kts.write_text(new, encoding="utf-8")
            print("[ok] build.gradle.kts compileSdk -> 36")
        else:
            print("[warn] build.gradle.kts 未匹配到 compileSdk，保持默认")
        return True

    if groovy.exists():
        s = groovy.read_text(encoding="utf-8")
        if re.search(r"compileSdkVersion\s+36\b", s):
            print("[skip] build.gradle compileSdk 已是 36")
            return True
        new = re.sub(r"compileSdkVersion\s+flutter\.compileSdkVersion",
                     "compileSdkVersion 36", s, count=1)
        if new != s:
            groovy.write_text(new, encoding="utf-8")
            print("[ok] build.gradle compileSdk -> 36")
        else:
            print("[warn] build.gradle 未匹配到 compileSdk，保持默认")
        return True

    print("[FAIL] 找不到 app/build.gradle(.kts)")
    return False


# 经典蓝牙 discovery 的 Kotlin 实现：注入 MainActivity.kt。
# 通过 MethodChannel("detect_app/classic_bt") + EventChannel("detect_app/classic_bt/events")
# 把 BluetoothAdapter.startDiscovery 的 ACTION_FOUND 结果（名称/MAC/RSSI/CoD）回传 Dart。
# 注意：不能用 str.format（Kotlin 代码里满是大括号），用 __PKG__ 占位替换。
CLASSIC_BT_KOTLIN = r'''package __PKG__

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var btAdapter: BluetoothAdapter? = null
    private var receiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "detect_app/classic_bt")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startDiscovery" -> result.success(startDiscovery())
                    "stopDiscovery" -> { stopDiscovery(); result.success(true) }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "detect_app/classic_bt/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) { eventSink = events }
                override fun onCancel(args: Any?) { eventSink = null }
            })
    }

    private fun hasBtPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) return false
            if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) return false
        }
        return true
    }

    private fun startDiscovery(): Boolean {
        if (!hasBtPermission()) return false
        try {
            val mgr = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            btAdapter = mgr.adapter
            if (btAdapter == null || !btAdapter!!.isEnabled) return false
            stopDiscovery()
            receiver = object : BroadcastReceiver() {
                @Suppress("DEPRECATION")
                override fun onReceive(ctx: Context?, intent: Intent?) {
                    if (intent?.action != BluetoothDevice.ACTION_FOUND) return
                    try {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE) ?: return
                        val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt()
                        var name = ""
                        var mac = ""
                        var cod = 0
                        try {
                            name = device.name ?: ""
                            mac = device.address ?: ""
                            cod = device.bluetoothClass?.deviceClass ?: 0
                        } catch (_: Exception) {}
                        eventSink?.success(mapOf("name" to name, "mac" to mac, "rssi" to rssi, "cod" to cod))
                    } catch (_: Exception) {}
                }
            }
            val filter = IntentFilter(BluetoothDevice.ACTION_FOUND)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            return btAdapter!!.startDiscovery()
        } catch (_: Exception) {
            return false
        }
    }

    private fun stopDiscovery() {
        try { receiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        receiver = null
        try { btAdapter?.cancelDiscovery() } catch (_: Exception) {}
    }

    override fun onDestroy() {
        stopDiscovery()
        super.onDestroy()
    }
}
'''


def patch_classic_bt() -> bool:
    """把经典蓝牙 discovery 注入 flutter create 生成的 MainActivity.kt。
    找不到 .kt 时回退 .java（旧模板），都找不到则告警但不阻断（经典蓝牙静默降级）。"""
    src = ROOT / "android/app/src/main"
    kt = list(src.rglob("MainActivity.kt"))
    java = list(src.rglob("MainActivity.java"))

    if kt:
        p = kt[0]
        s = p.read_text(encoding="utf-8")
        m = re.search(r"package\s+([\w.]+)", s)
        pkg = m.group(1) if m else "com.zdjc.detect_app"
        p.write_text(CLASSIC_BT_KOTLIN.replace("__PKG__", pkg), encoding="utf-8")
        print("[ok] 经典蓝牙 discovery 已注入 MainActivity.kt (package=%s)" % pkg)
        return True

    if java:
        print("[warn] 检测到 MainActivity.java（旧模板），经典蓝牙注入仅支持 Kotlin，已跳过")
        return True

    print("[warn] 找不到 MainActivity.kt，经典蓝牙注入跳过（Dart 端会静默降级）")
    return True


def main() -> int:
    ok = patch_manifest() and patch_min_sdk() and patch_compile_sdk() and patch_classic_bt()
    if ok:
        print("\n补丁完成，可以执行 flutter build apk --release")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
