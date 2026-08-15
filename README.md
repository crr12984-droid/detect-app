# 智能终端检测定位系统（真实数据版 · Flutter）

通过设备自身的 **WiFi / 蓝牙模块真实扫描**周边网络与蓝牙设备，解析品牌、信号、距离，
并做定位追踪。**非模拟数据、非演示套壳**，是可直接用于实战的安卓应用源码工程。

---

## 一、构建本 APK 需要的环境（必须在本机准备）

> 当前 AI 运行环境**没有** Flutter / Android SDK / Java，无法在此编译出 `.apk`。
> 以下环境装在你自己的电脑（Windows / macOS / Linux 均可）上。

| 组件 | 版本要求 | 用途 | 安装 |
|---|---|---|---|
| **Flutter SDK** | ≥ 3.16（含 Dart ≥ 3.2） | 编译 Dart + 出 APK | https://docs.flutter.dev/get-started |
| **Android SDK** | Platform 34 + Build-Tools 34 | 安卓原生构建 | 随 Android Studio 安装 |
| **JDK** | **17** | AGP 8 要求 | `sdkmanager` 或单独装 |
| **Android Studio**（推荐） | 最新 | 管理 SDK、签名出包、连真机 | https://developer.android.com/studio |
| **USB 调试** | — | 真机安装测试 | 手机/平板「开发者选项→USB 调试」 |

验证（本机命令行）：
```bash
flutter --version      # 应 >= 3.16
java -version          # 应 17.x
adb devices            # 连上真机后能看到设备序列号
```

---

## 二、出包步骤（本机执行）

```bash
# 1. 进入工程
cd detect_app

# 2. 让 Flutter 生成与当前版本匹配的原生安卓脚手架（android/ 等）
flutter create --platforms=android .

# 3. 用本工程提供的清单（含 WiFi/蓝牙权限）覆盖自动生成的清单
#    （文件已备好：android/app/src/main/AndroidManifest.xml）

# 4. 拉取依赖
flutter pub get

# 5. 连上手机/平板（USB 调试已开），直接装到设备验证
flutter run

# 6. 正式出包（release，按 ABI 拆分，体积更小）
flutter build apk --release --split-per-abi
```

产物位于：
`build/app/outputs/flutter-apk/app-arme64-v8a-release.apk`（主流手机/平板）
`build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`（老旧 32 位设备）

拷贝到设备双击安装，或用 `adb install <apk>`。

> 上架/分发签名：`flutter build apk` 用 debug 密钥即可本地安装；
> 若要对外用自有密钥签名，在 `android/app/build.gradle` 的 `signingConfigs`
> 配置 keystore（参见官方文档）。

---

## 三、真实数据能力（务必了解边界）

本应用调用的是**安卓公开 API**，能力受平台规范限制：

### ✅ 能真实获取到的
- **WiFi**：周边 **AP / 路由器 / 热点** 的真实列表 —— SSID、BSSID(MAC)、实时信号(dBm)、
  加密方式(WPA2/WPA3 等)。品牌由 BSSID 前 3 字节 OUI 解析（含华为/荣耀/小米/OPPO/vivo/
  一加/realme/魅族/中兴/Apple/Samsung 等）。
- **蓝牙 BLE**：周边**正在广播的蓝牙低功耗设备**真实列表 —— 名称、MAC、实时 RSSI。
- **经典蓝牙**：本工程聚焦 BLE；如需已配对经典设备，可在 `ble_scanner` 基础上扩展
  `BluetoothAdapter.getBondedDevices()`。
- **距离**：由实时 RSSI 经验模型估算（非米级精确定位）。
- **定位追踪**：进入设备后每秒重新扫描，刷新真实 RSSI，绘制实测趋势。

### ⚠️ 平台硬性边界（不是我们不想做，是安卓不允许）
- **普通应用无法"嗅探/监控模式"扫描 WiFi 客户端**（即看不到别人手机连哪个路由器的
  底层流量），只能扫到**路由器/热点本身**。要解析"某台手机"需该手机自身做热点或
  蓝牙广播——本应用对这类设备可正常发现。
- **蓝牙扫描必须授予位置权限**（Android 6+），否则系统直接返回空。首次进入会弹权限请求。
- **WiFi RTT 精确定位**需双方都支持 802.11mc（多数消费设备不支持），否则回退 RSSI 估算。
- 后台持续扫描受系统节流限制，本应用为前台交互式扫描。

---

## 四、工程结构
```
detect_app/
├── pubspec.yaml                     # 依赖：flutter_blue_plus / wifi_scan / permission_handler / sensors_plus
├── android/app/src/main/AndroidManifest.xml   # 权限 + 启动 Activity
├── lib/
│   ├── main.dart
│   ├── models/device.dart           # 设备模型（含 RSSI→距离/格数）
│   ├── core/
│   │   ├── distance.dart            # RSSI→距离、RSSI→8格
│   │   ├── brand_db.dart            # OUI→品牌 单一数据源
│   │   ├── permissions.dart         # 运行时权限申请
│   │   ├── wifi_scanner.dart        # 真实 WiFi 扫描
│   │   └── ble_scanner.dart         # 真实 BLE 扫描
│   └── features/
│       ├── detection/detection_page.dart     # 检测主页（WiFi/蓝牙 Tab + 真实列表）
│       └── positioning/positioning_page.dart # 定位追踪（实时 RSSI + 趋势）
```

## 五、后续可扩展（真实能力加深）
- `sensors_plus` 接陀螺仪/罗盘，做方位+信号融合定位（原型的定位环逻辑可迁移至此）。
- WiFi RTT（`WifiRttManager`）在支持设备上做更精准测距。
- 品牌 OUI 库扩充为权威 IEEE OUI 数据库（当前为示例集合，需按真实 OUI 校准）。
- 报告导出（PDF/Excel）、云端同步（见 `APK开发规划清单.md` M2/M3）。
