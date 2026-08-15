# 如何得到「可安装的实战 APK」

本工程是**真实数据版**（调用设备 WiFi / 蓝牙模块扫描周边真实网络与设备），不是演示套壳。
APK 必须由 Android SDK + Flutter 编译并签名后生成。下面两条路都能让你拿到真包，**选一条即可**。

> ⚠️ 关于"在本 AI 环境里自动安装"：当前 WorkBuddy 运行沙箱**无外网、无 winget/choco/scoop、系统工具被禁用**，无法在此下载/安装 Flutter 与 Android SDK，也无法在此编译出 `.apk`。以下方案均在**你自己的电脑**上完成安装与编译（或交给云端 CI 编译）。

---

## 方案 A：云端一键出包（推荐，你本机零安装）

完全不需要在你电脑上装任何 SDK，由 GitHub 的服务器替你编译并签名。

1. 在 GitHub 新建一个**空仓库**（如 `detect-app`）。
2. 把 `detect_app/` 目录下的内容作为仓库根目录推上去（`detect_app/.github/workflows/build-apk.yml` 必须随仓库一起）。
3. 进入仓库 **Actions → Build Release APK → Run workflow**（手动点一次；或推送即自动触发）。
4. 跑完后到 **Actions → 该次运行 → Artifacts** 下载 `detect-app-release-apk`，里面就是 `app-release.apk`。
5. 把 APK 拷到手机/平板（或 `adb install app-release.apk`）即可安装。

> 该工作流已配好：Ubuntu + Java17 + Flutter stable + Android SDK → `flutter create` 生成原生工程 →
> `ci/patch_android.py` 注入 WiFi/蓝牙权限 → `flutter build apk --release`，产物自动上传为 Artifact。
> 若要上架或对外发布，需自建正式签名 keystore（见下方"正式签名"）。

### A-1 更新已有仓库（替换文件 + 提交）

当本地源码有修改（例如修完 CI 报错）要同步到 GitHub 重新触发出包时：

```bash
cd detect_app
git add -A
git commit -m "fix: 说明本次改动"
git push
```

若本地是**新初始化的仓库**、而 GitHub 上已有一次旧提交（历史不同源），push 会被拒绝。
此时用强制推送覆盖远端（远端只是旧代码，可安全覆盖）：

```bash
git remote add origin https://github.com/<你的用户名>/<仓库名>.git   # 首次才需要
git push -u origin main --force
```

> 首次推送会弹出 GitHub 登录（Git for Windows 自带凭据管理器，浏览器授权即可）；
> 若用命令行密码方式，需改用 Personal Access Token（GitHub 已不支持账号密码推送）。

**不想用命令行？** 也可在 GitHub 网页直接改：进仓库 → 点开要替换的文件 → 铅笔图标 → 全选粘贴新内容 →
底部 `Commit changes`。提交后 Actions 会自动重跑。删除文件同理（文件页 → 垃圾桶图标）。

---

## 方案 B：本机一键安装并出包（Windows）

适合你愿意在自己 Windows 电脑上一次性装好工具链、之后可反复构建。

1. 以**管理员身份**打开 PowerShell（Win+X → 终端(管理员)）。
2. 运行本目录的脚本：
   ```powershell
   powershell -ExecutionPolicy Bypass -File setup_windows.ps1
   ```
   脚本会自动：装 Git / OpenJDK17 / Flutter / Android Studio → 装 Android SDK 组件并同意许可 → 设环境变量 → `flutter build apk --release`。
3. 脚本结束后**务必新开一个终端窗口**（PATH 才生效）。
4. 产物在 `detect_app\build\app\outputs\flutter-apk\app-release.apk`。

> 前提：你的 Windows 电脑能联网、有管理员权限、磁盘剩余 ≥ 15GB。
> macOS / Linux 用户：可参考 `build-apk.yml` 的步骤（subosito/flutter-action + sdkmanager）手动安装，思路一致。

---

## 正式签名（上架 / 对外分发用）

默认 `flutter build apk --release` 用调试密钥签名，可侧载安装，但不适合上架。正式发布请：

```bash
keytool -genkey -v -keystore upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
然后在 `android/app/build.gradle` 的 `android { }` 内加 `signingConfigs` 引用该 keystore，并将 `buildTypes.release.signingConfig` 指向它，再重新 `flutter build apk --release`。

---

## 真机能力边界（务必知悉）

- ✅ **真实可扫到**：周边 WiFi 路由器/热点（SSID、BSSID、实时 dBm、加密方式）；周边正在广播的蓝牙 BLE 设备（名称、MAC、实时 RSSI）。品牌由 MAC 的 OUI 解析（华为/荣耀/小米/OPPO/vivo/一加/realme/魅族/中兴/Apple/Samsung 等）。
- ⚠️ **普通 App 做不到**：无法用监听模式嗅探别人手机连了哪个 WiFi（看不到客户端底层流量），只能扫到路由器/热点本身与蓝牙广播设备。要"发现某台手机"，需它开了热点或蓝牙在广播。
- ⚠️ 蓝牙扫描**强制需要位置权限**（Android 6+），首次进入会弹窗申请；WiFi RTT 精确定位需双方支持 802.11mc，否则回退 RSSI 估算距离。
