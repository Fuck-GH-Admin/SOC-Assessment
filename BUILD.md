# 编译打包指南

## 环境要求

### 必须
| 工具 | 版本 | 用途 |
|------|------|------|
| Flutter SDK | >=3.44 | 主框架 |
| Dart | >=3.12 | Flutter 内置 |
| Git | 任意 | 源码管理 |

### 按平台

| 平台 | 工具 | 备注 |
|------|------|------|
| **Windows** | Visual Studio 2022 Build Tools（含 ATL） | 需安装 "C++ ATL for v143 build tools" 组件 |
| **Android** | Android SDK 36+ | 需接受 licenses，需 `cmdline-tools` |
| **macOS / iOS** | Xcode 16+ | 本指南暂未覆盖 |

## 快速开始

```powershell
# 1. 克隆仓库
git clone https://github.com/Fuck-GH-Admin/SOC-Assessment.git
cd SOC-Assessment

# （可选）清理旧版残留（Vue 项目），避免干扰
Remove-Item -Recurse -Force node_modules, dist, dist_electron -ErrorAction SilentlyContinue

cd soc_app

# 2. 获取依赖
flutter pub get

# 3. 运行测试（建议先验证环境）
flutter test

# 4. 开发模式运行
flutter run -d windows   # Windows 桌面
flutter run -d chrome    # Web 调试
```

## 编译打包

### Windows（x64）

```powershell
cd soc_app

# 首次构建前需清理（若之前 build 过）
flutter clean

# 重要：必须从 VS 开发者命令提示符构建，以正确加载 ATL 路径
# 方法一：直接使用 vcvars64
"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
flutter build windows --release

# 方法二：一行命令（PowerShell）
cmd /c "`"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat`" -vcvars_ver=14.44 >nul && flutter build windows --release"
```

**产物位置：**
```
build\windows\x64\runner\Release\
  soc_app.exe              # 主程序
  flutter_windows.dll      # Flutter 引擎
  *.dll                    # 插件（flutter_secure_storage、sqlite3 等）
  data/                    # 运行时资源
```

**分发：** 将 `Release\` 下所有文件打包为 zip 即可分发，无额外运行时依赖。

**注意事项：**
- 若遇到 `atlstr.h` 找不到，需安装 ATL 组件：
  ```
  "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Component.VC.ATL --quiet --norestart
  ```
- 若 MSVC 版本 >14.44，将 `-vcvars_ver=14.44` 改为对应版本

### Android（APK）

```powershell
cd soc_app

# 调试 APK（无需签名）
flutter build apk --debug

# 发布 APK（需接受 Android licenses，默认 debug 签名）
flutter doctor --android-licenses  # 首次需接受
flutter build apk --release
```

**产物位置：**
```
build\app\outputs\flutter-apk\
  app-debug.apk    # 调试版
  app-release.apk  # 发布版（默认 debug 签名）
```

**关于签名：**
正式发布需配置签名密钥。参考 [Flutter 官方指南](https://docs.flutter.dev/deployment/android#signing-the-app)，在 `android/app/build.gradle.kts` 中配置 `signingConfigs`。

**注意事项：**
- Android 构建需要网络访问 `maven.google.com`（国内需代理）
- 若 `cmdline-tools` 缺失，通过 Android Studio → SDK Manager → SDK Tools 安装
- 项目路径含中文时，已在 `android/gradle.properties` 中配置 `android.overridePathCheck=true` 绕过限制
- `android/build.gradle.kts` 中已配置 `subprojects { afterEvaluate { ... compileSdkVersion(36) } }`，无需手动修改
- 项目路径含中文时，已在 `android/gradle.properties` 中配置 `android.overridePathCheck=true` 绕过限制
- `android/build.gradle.kts` 中已配置 `subprojects { afterEvaluate { ... compileSdkVersion(36) } }`，无需手动修改

### 代理配置（国内网络必需）

Android 构建需要下载 Gradle 和 Maven 依赖，国内网络通常需要代理。仓库不包含硬编码代理，请自行配置：

```powershell
# 方式一：设置环境变量（推荐）
$env:HTTP_PROXY = "http://127.0.0.1:7890"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
flutter build apk --release

# 方式二：写入用户级 gradle.properties（不提交到仓库）
# 编辑 ~/.gradle/gradle.properties:
# systemProp.http.proxyHost=127.0.0.1
# systemProp.http.proxyPort=7890
# systemProp.https.proxyHost=127.0.0.1
# systemProp.https.proxyPort=7890
```

### Web（渐进式 Web 应用）

```powershell
cd soc_app
flutter build web --release
```

产物位于 `build/web/`，部署到任意静态服务器即可。

### 全部平台一键构建

```powershell
cd soc_app

# Windows（需 VS 命令行环境）
flutter build windows --release

# Android
flutter build apk --release

# Web
flutter build web --release
```

## 版本号管理

版本号在 `soc_app/pubspec.yaml` 中定义：

```yaml
version: 1.1.0+1   # 语义版本+构建号
```

- `1.1.0` — 语义版本（major.minor.patch）
- `+1` — Android buildCode / Windows build 后缀

构建时可通过参数覆盖：

```powershell
flutter build apk --release --build-name=1.2.0 --build-number=2
flutter build windows --release --build-name=1.2.0 --build-number=2
```

## 常见问题

### Q: 项目路径含中文导致构建失败

**现象：** `CUSTOMBUILD : error : Unable to read file` 或 MSB8066

**解决：** 将项目复制到纯英文路径（如 `C:\dev\soc-app`）再构建。

### Q: atlstr.h 找不到

**原因：** Visual Studio Build Tools 未安装 ATL 组件。

**解决：** 以管理员身份运行：
```powershell
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Component.VC.ATL --quiet --norestart
```

### Q: maven.google.com 超时

**原因：** 国内网络环境无法直连 Google Maven。

**解决：** 使用代理，或配置 Gradle 镜像（如阿里云）：
编辑 `android/build.gradle.kts`，添加：
```kotlin
allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        mavenCentral()
    }
}
```

### Q: flutter pub get 网络慢

**解决：** 配置 Flutter 镜像：
```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

### Q: 缺少 cmdline-tools

**解决：** 通过 Android Studio → SDK Manager → SDK Tools → 勾选 "Android SDK Command-line Tools (latest)" → 应用

## 开发工具推荐

| 工具 | 用途 |
|------|------|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 主框架 |
| [Android Studio](https://developer.android.com/studio) | Android 开发 + 模拟器管理 |
| [Visual Studio 2022](https://visualstudio.microsoft.com/vs/) | Windows 原生开发 |
| [VS Code](https://code.visualstudio.com/) | 轻量编辑器（推荐安装 Flutter 扩展） |
| [GitHub CLI (gh)](https://cli.github.com/) | 创建 Release、管理 PR |
