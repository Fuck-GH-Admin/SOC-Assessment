#!/usr/bin/env bash
# 构建碳盾 SOC-Shield 的 .deb 包（amd64）。
# 用法: bash tooling/build-deb.sh
#
# 前置: flutter build linux --release 的产物（soc_app/build/linux/x64/release/bundle）
# 依赖: dpkg-deb（Ubuntu 自带）。产物: release/soc-shield_<version>_amd64.deb
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${ROOT}/soc_app"
BUNDLE="${APP_DIR}/build/linux/x64/release/bundle"
VERSION="$(sed -n 's/^version: \([^-+]*\).*/\1/p' "${APP_DIR}/pubspec.yaml" | head -1)"
BUILD="${ROOT}/.tools/deb-build"
OUT="${ROOT}/release"

if [[ ! -x "${BUNDLE}/soc_app" ]]; then
  echo "错误: 未找到 Linux 构建产物，先执行:" >&2
  echo "  source tooling/dev-env.sh && cd soc_app && flutter build linux --release" >&2
  exit 1
fi

PKG_NAME="soc-shield"
INSTALL_DIR="/opt/${PKG_NAME}"

# --- 包目录树 ---
rm -rf "${BUILD}"
DEB_DIR="${BUILD}/${PKG_NAME}"
mkdir -p "${DEB_DIR}/DEBIAN" \
         "${DEB_DIR}${INSTALL_DIR}" \
         "${DEB_DIR}/usr/bin" \
         "${DEB_DIR}/usr/share/applications" \
         "${DEB_DIR}/usr/share/icons/hicolor/256x256/apps" \
         "${DEB_DIR}/usr/share/doc/${PKG_NAME}"

# 应用文件
cp -r "${BUNDLE}/." "${DEB_DIR}${INSTALL_DIR}/"

# 启动器：优先用包内自带 Flutter 运行时的 bundle；系统库按需加载
cat > "${DEB_DIR}/usr/bin/${PKG_NAME}" <<LAUNCHER
#!/usr/bin/env bash
# 碳盾 SOC-Shield 启动器
exec "${INSTALL_DIR}/soc_app" "\$@"
LAUNCHER
chmod +x "${DEB_DIR}/usr/bin/${PKG_NAME}"

# 图标与桌面入口
ICON_SRC="$(ls "${APP_DIR}/assets/icons/"*.png 2>/dev/null | head -1 || true)"
if [[ -n "${ICON_SRC}" ]]; then
  cp "${ICON_SRC}" "${DEB_DIR}/usr/share/icons/hicolor/256x256/apps/${PKG_NAME}.png"
else
  echo "警告: 未找到应用图标，跳过图标安装" >&2
  rmdir "${DEB_DIR}/usr/share/icons/hicolor/256x256/apps" 2>/dev/null || true
fi

cat > "${DEB_DIR}/usr/share/applications/${PKG_NAME}.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=碳盾 · SOC-Shield
Comment=土壤有机碳评估系统 / Soil Organic Carbon Assessment
Exec=${PKG_NAME}
Icon=${PKG_NAME}
Categories=Science;
Terminal=false
DESKTOP

# 版权文件
cat > "${DEB_DIR}/usr/share/doc/${PKG_NAME}/copyright" <<COPYRIGHT
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ${PKG_NAME}
Source: https://github.com/Fuck-GH-Admin/SOC-Assessment

Files: *
Copyright: 2026 SOC-Shield
License: MIT
_license_placeholder
COPYRIGHT
# 用 LICENSE 文件替换占位
if [[ -f "${ROOT}/LICENSE" ]]; then
  python3 - "$ROOT/LICENSE" "${DEB_DIR}/usr/share/doc/${PKG_NAME}/copyright" <<'PY'
import sys
lic = open(sys.argv[1], encoding='utf-8').read()
path = sys.argv[2]
text = open(path, encoding='utf-8').read()
open(path, 'w', encoding='utf-8').write(text.replace('_license_placeholder', lic))
PY
fi

# --- 控制文件 ---
INSTALLED_SIZE="$(du -sk "${DEB_DIR}" | awk '{print $1}')"
cat > "${DEB_DIR}/DEBIAN/control" <<CONTROL
Package: ${PKG_NAME}
Version: ${VERSION}
Section: science
Priority: optional
Architecture: amd64
Installed-Size: ${INSTALLED_SIZE}
Depends: libgtk-3-0t64 | libgtk-3-0, libglib2.0-0t64 | libglib2.0-0, libsqlite3-0
Recommends: libsecret-1-0
Suggests: libnotify4
Maintainer: SOC-Shield <tom20061217@163.com>
Description: 碳盾 · SOC-Shield — 土壤有机碳评估系统
 土壤有机碳（SOC）评估工具：按施肥处理、侵蚀深度与土层查询
 实测数据，计算碳库与 CK 静态差异，提供秸秆还田碳输入情景、
 恢复力评估与 PDF 报告。
 .
 本包将应用安装到 ${INSTALL_DIR}，用户数据保存在
 用户文档目录（数据库与评估报告），卸载不会删除用户数据。
Homepage: https://github.com/Fuck-GH-Admin/SOC-Assessment
CONTROL

# conffiles：无配置文件，显式声明避免 lintian 警告缺失
# postinst：刷新桌面/图标缓存
cat > "${DEB_DIR}/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -qf /usr/share/icons/hicolor || true
fi
exit 0
POSTINST
cat > "${DEB_DIR}/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q || true
fi
exit 0
POSTRM
chmod 755 "${DEB_DIR}/DEBIAN/postinst" "${DEB_DIR}/DEBIAN/postrm"

# --- 权限规整（lintian: 标准目录/文件权限）---
find "${DEB_DIR}" -type d -exec chmod 755 {} +
find "${DEB_DIR}" -type f -exec chmod 644 {} +
chmod 755 "${DEB_DIR}/usr/bin/${PKG_NAME}" \
          "${DEB_DIR}${INSTALL_DIR}/soc_app" \
          "${DEB_DIR}/DEBIAN/postinst" "${DEB_DIR}/DEBIAN/postrm"
find "${DEB_DIR}${INSTALL_DIR}/lib" -type f -name "*.so" -exec chmod 644 {} +

# --- 构建 ---
mkdir -p "${OUT}"
DEB_PATH="${OUT}/${PKG_NAME}_${VERSION}_amd64.deb"
rm -f "${DEB_PATH}"
dpkg-deb --root-owner-group --build "${DEB_DIR}" "${DEB_PATH}"

echo
echo "产物: ${DEB_PATH}"
dpkg-deb --info "${DEB_PATH}" | head -20

# lintian 存在则做静态检查。以下 E 是 Flutter bundle 的已知误报，不影响安装：
#   dir-or-file-in-opt / embedded-library / unstripped-binary-or-object /
#   missing-dependency-on-libc / shared-library-lacks-prerequisites
# （/opt 自包含部署是本包设计；bundle 自带 freetype/jpeg；Flutter 产物不 strip）
if command -v lintian >/dev/null 2>&1; then
  echo
  echo "lintian 检查（已知 Flutter 误报已过滤）:"
  lintian --profile ubuntu \
    --suppress-tags dir-or-file-in-opt,embedded-library,unstripped-binary-or-object,missing-dependency-on-libc,shared-library-lacks-prerequisites \
    "${DEB_PATH}" || true
fi
