# SOC-Shield 发布产物命名规范

## 统一模板

```text
SOC-Shield-<版本>-<平台标识>-<架构>.<扩展名>
```

- 版本：语义化版本（取自 `soc_app/pubspec.yaml`，与 git tag 一致）
- 平台标识与架构约定：

| 产物 | 文件名 | 说明 |
|---|---|---|
| Windows 安装包 | `SOC-Shield-1.1.5-windows-x64-setup.exe` | Inno Setup 安装向导 |
| Windows 绿色版 | `SOC-Shield-1.1.5-windows-x64.zip` | 解压即用 |
| Android | `SOC-Shield-1.1.5-android-arm64.apk` | 主 APK（通用 ABI） |
| Linux AppImage | `SOC-Shield-1.1.5-linux-x86_64.AppImage` | 免安装单文件 |
| Linux deb 包 | `soc-shield_1.1.5_amd64.deb` | Debian 命名规范（包名_版本_架构），不套模板 |
| 源码包 | `SOC-Shield-1.1.5-source.zip` | `git archive` |

## 规则

1. 除 deb（受 Debian 命名规范约束）外，一律使用统一模板；大写 `SOC-Shield` 前缀保证 Release 资产列表排序时聚在一起。
2. 平台标识用小写（`windows` / `android` / `linux` / `source`），架构可省略时省略（source 无架构）。
3. 旧命名（`soc-app-*`、`soc-shield-setup-*`、`soc-shield-<ver>-x86_64.AppImage`）废弃。
4. 修改命名时必须同步三处：本文件、`.github/workflows/release.yml`、`tooling/build-appimage.sh` 与 `tooling/build-deb.sh`。
