<#
  setup_windows.ps1  -  One-command local installer for the Detect App build toolchain on Windows.
  Run this on YOUR OWN Windows PC (Win10 21H2+ / Win11) as Administrator, with internet access.

  What it does (automatically):
    1. Ensures winget is available (downloads installer if missing)
    2. Installs Git, OpenJDK 17, Flutter, Android Studio (which provides the Android SDK)
    3. Installs required Android SDK packages (platform-tools, android-34, build-tools 34.0.0) and accepts licenses
    4. Sets JAVA_HOME / ANDROID_HOME / PATH
    5. Builds the release APK into  detect_app\build\app\outputs\flutter-apk\app-release.apk

  After running, OPEN A NEW PowerShell/terminal window so the updated PATH takes effect.
  Then you can also use:  cd detect_app ; flutter build apk --release
#>

$ErrorActionPreference = 'Stop'

function Require-Admin {
  $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as Administrator (right-click -> Run with PowerShell as admin)."
    exit 1
  }
}
function Refresh-Env {
  $machine = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('PATH', 'User')
  $env:PATH = "$machine;$user"
}
function Install-App($id) {
  Write-Host ">> Installing $id ..." -ForegroundColor Cyan
  winget install --id $id --accept-package-agreements --accept-source-agreements -e --silent
  if ($LASTEXITCODE -ne 0) { throw "Failed to install $id (winget exit $LASTEXITCODE)" }
}

Require-Admin
Refresh-Env

# 1) Ensure winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host ">> winget not found, downloading App Installer..." -ForegroundColor Yellow
  $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.WindowsAppRuntime.1.5_x64.msixbundle"
  # Fallback: install via the Store URI is not scriptable; download the CLI bundle instead.
  $cli = "https://github.com/microsoft/winget-cli/releases/latest/download/winget-cli_x64.msixbundle"
  Invoke-WebRequest -Uri $cli -OutFile "$env:TEMP\winget.msixbundle"
  Add-AppxPackage -Path "$env:TEMP\winget.msixbundle"
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget still unavailable. Install 'App Installer' from Microsoft Store manually." }
}

# 2) Toolchain
Install-App 'Git.Git'
Install-App 'EclipseAdoptium.Temurin.17.JDK'
Install-App 'Google.Flutter'
Install-App 'Google.AndroidStudio'

Refresh-Env

# 3) Locate SDK and tools
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
if (-not (Test-Path $sdk)) {
  # Android Studio may place it elsewhere; search common path
  $alt = "C:\Android\Sdk"
  if (Test-Path $alt) { $sdk = $alt } else { throw "Android SDK not found at $sdk. Open Android Studio once to let it install the SDK." }
}
$sdkmanager = Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path $sdkmanager)) {
  # older layout without 'latest'
  $sdkmanager = Join-Path $sdk 'tools\bin\sdkmanager.bat'
}
if (-not (Test-Path $sdkmanager)) { throw "sdkmanager not found under $sdk. Open Android Studio -> SDK Manager and install 'Android SDK Command-line Tools'." }

Write-Host ">> Installing Android SDK packages (this downloads ~1GB, be patient)..." -ForegroundColor Cyan
& $sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
& $sdkmanager --licenses

# 4) Env vars
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdk, 'User')
[Environment]::SetEnvironmentVariable('JAVA_HOME', (Get-ChildItem "C:\Program Files\Eclipse Adoptium\*17*" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName, 'User')
Refresh-Env

# 5) Build (assumes detect_app is the current directory or pass its path as arg)
$proj = if ($args[0]) { $args[0] } else { $PSScriptRoot }
Set-Location $proj
Write-Host ">> Building release APK in $proj ..." -ForegroundColor Cyan
flutter config --android-sdk $sdk

# Native android project is NOT committed to the repo: it must be generated,
# otherwise a hand-written manifest makes flutter create skip generation and
# the app crashes (missing flutterEmbedding v2).
# --project-name is required: folder name may contain '-', invalid for Dart.
if (Test-Path (Join-Path $proj 'android')) { Remove-Item (Join-Path $proj 'android') -Recurse -Force }
flutter create --platforms=android --project-name detect_app --org com.zdjc .

# Re-apply WiFi/Bluetooth permissions, Chinese app label and minSdk 23
python ci\patch_android.py

flutter pub get
flutter build apk --release

Write-Host ""
Write-Host "DONE. APK at: $proj\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
