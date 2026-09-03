# 开发环境标准

本文件定义 SOC-Shield（碳盾）后续开发、审查和发布使用的工具链。版本升级必须同步修改本文件、`tooling/check-environment.sh`（如有版本判断）和发布记录；不要只依赖“当前机器能运行”。

## 版本基线

| 工具 | 标准版本 | 用途 | 来源/备注 |
| --- | --- | --- | --- |
| Ubuntu | 26.04 LTS（x86_64） | 当前参考开发主机 | 其他 Linux 发行版需自行验证 |
| Flutter | 3.44.2 stable | 应用框架、构建和测试 | 项目 SDK 基线 |
| Dart | 3.12.2 | Flutter 内置 SDK | 不单独升级 |
| Java/JDK | 21 | Android/Gradle 编译 | 必须同时提供 `java` 和 `javac` |
| Android SDK Platform | 36 | Android 编译目标 | `compileSdk = 36` |
| Android Build Tools | 36.1.0 | APK 打包 | 与本机 SDK 一致 |
| Android NDK | 28.2.13676358 | 原生插件/SQLite 构建 | Flutter 构建按需安装 |
| Android CMake | 3.22.1 | 原生插件构建 | 随 Android SDK 安装 |
| Android Platform Tools | 37.0.1 或更新 | `adb` 调试 | 与设备兼容即可 |
| Gradle Wrapper | 9.1.0 | Android 构建 | 由 `soc_app/android/gradle/wrapper` 固定 |
| Node.js | 22.x | 说明书渲染工具 | `markdown-it` 依赖 |
| Google Chrome | 151 或兼容 Chromium | HTML 到 PDF | 仅文档发布需要 |
| SQLite runtime | `libsqlite3-0` | Linux 上的 Drift 单元测试 | 初始化脚本提供 FFI 兼容链接 |

项目的 Dart 约束在 [`soc_app/pubspec.yaml`](../../soc_app/pubspec.yaml) 中为 `^3.12.2`。Flutter SDK 使用仓库内 `.tools/flutter` 时，版本必须精确为 3.44.2；`.tools` 已加入 `.gitignore`，SDK 不会提交到仓库。

初始化脚本只下载两个固定归档，并在解包前验证 SHA-256：Flutter `b0de1d19754688ec6769c9a067db3b0594479d3d767f971bfecfc132904c8d5e`，Temurin JDK `e4446ff06a276155697597cc0f1b15da004ff083f4964a35271ecee567177370`。

## Ubuntu 主机基础依赖

当前开发主机已经具备这一组依赖，现阶段无需重复安装。新建 Ubuntu 开发机时，先安装以下系统包：

```bash
sudo apt update
sudo apt install ca-certificates curl git tar xz-utils unzip zip libsqlite3-0
```

- `curl`、`tar`、`xz-utils`：下载并解包项目固定的 Flutter 与 JDK 归档。
- `git`：获取源码和管理版本；`unzip`、`zip`：Flutter、Gradle 和发布流程使用。
- `libsqlite3-0`：Linux 上运行 Drift/SQLite FFI 测试所需的运行时库。
- Node.js 22 与 Google Chrome 由系统或个人工具管理方式安装；说明书渲染要求命令分别为 `node` 和 `google-chrome`。Ghostwriter 仅用于手工编辑 Markdown，Pandoc 不在当前渲染链中。

## 初始化

在仓库根目录执行：

```bash
# 下载并解包 Flutter 3.44.2 到 .tools
bash tooling/setup-dev-environment.sh

# 让当前 shell 使用仓库工具链
source tooling/dev-env.sh

# 检查路径、版本和 Android SDK
bash tooling/check-environment.sh
```

`dev-env.sh` 不修改用户 shell 配置，只对当前 shell 生效。它仅为 Flutter/Dart 子进程使用 `.tools/home`，避免在用户目录留下工具状态；不会修改当前终端的 `$HOME`。长期使用时，可在个人 `~/.bashrc` 中手动加入 `source /绝对路径/SOC-Assessment/tooling/dev-env.sh`；不要把个人绝对路径提交到仓库。

## 日常验证

```bash
source tooling/dev-env.sh
cd soc_app
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

生成代码或修改 Drift/Riverpod 注解后，先执行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

说明书渲染在仓库根目录执行：

```bash
node docs/user-guide/tooling/render.mjs
```

## Android 与桌面边界

- Android 构建要求 Android SDK 36、已接受许可证、JDK 21，以及可访问 Gradle/Maven 仓库的网络。
- Release APK 必须保留 `INTERNET` 权限；详见 [`BUILD.md`](../../BUILD.md)。
- 需要在纯 ASCII 路径执行 Android Release 构建，避免 Flutter AOT 快照器对中文路径失败。
- Windows 构建不能在本 Linux 主机上完成；发布 Windows 包必须使用带 Visual Studio 2022、MSVC、ATL 和 Windows SDK 的 Windows 构建机。
- Linux 桌面构建另需 `clang`、`cmake`、`ninja-build` 和 GTK 开发包；它们不是 Android 验证的前置条件。
- Linux 单元测试需要系统 SQLite 运行时库（Ubuntu 包名 `libsqlite3-0`）。`setup-dev-environment.sh` 会在 `.tools/lib` 建立本地 `libsqlite3.so` 链接，避免要求安装开发包 `libsqlite3-dev`。

## Ubuntu/Linux 规划

Linux 桌面版暂不作为当前版本的构建目标，后续计划优先支持 Ubuntu，并以 `.deb` 作为主要分发格式。启用 Linux 构建时，建议在 Ubuntu 构建机安装以下软件包：

```bash
# Flutter Linux 桌面编译
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev libsqlite3-dev

# Debian 包构建与检查
sudo apt install dpkg-dev debhelper fakeroot lintian desktop-file-utils
```

用途说明：

- `clang`、`cmake`、`ninja-build`、`pkg-config`、`libgtk-3-dev`、`liblzma-dev`：Flutter Linux runner 的编译链。
- `libsecret-1-dev`：为 `flutter_secure_storage` 等安全存储插件提供 Linux 后端开发文件。
- `libsqlite3-dev`：为 Linux 原生 SQLite/Drift 构建提供头文件和链接文件；运行已打包应用至少需要 `libsqlite3-0`。
- `dpkg-dev`、`debhelper`、`fakeroot`：生成可重复的 `.deb` 包。
- `lintian`：检查 Debian 包元数据和依赖声明。
- `desktop-file-utils`：校验和刷新桌面入口文件。

发布包还应声明并验证运行时依赖（至少 GTK 3、GLib、SQLite；若启用安全存储则包含 Secret Service/libsecret 运行时），并提供：

- `/usr/bin` 下的应用启动器；
- `/usr/share/applications/` 下的 `.desktop` 文件；
- `/usr/share/icons/` 或应用专属资源目录下的图标；
- 卸载、升级和用户数据保留策略；
- 在受支持的 Ubuntu LTS 版本上的干净虚拟机安装测试。

在 Linux 目标正式启用前，不要把这些包加入 Android/Windows 构建机的必需依赖，也不要把 `.deb` 产物提交到仓库。

## 网络、密钥和缓存

- 不在仓库、日志、JSON、说明书或截图中写入真实 API Key。
- Flutter、Pub、Gradle 和 npm 缓存属于本机缓存，不应纳入版本控制。
- 受限网络环境请在当前 shell 设置 `HTTP_PROXY`/`HTTPS_PROXY`，或按组织规范配置镜像；`dev-env.sh` 会将这两个变量转换为 Gradle/JVM 的代理参数，并在使用代理时采用 TLS 1.2 与较长超时。仓库不硬编码代理。
