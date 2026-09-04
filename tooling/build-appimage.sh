#!/usr/bin/env bash
# 构建碳盾 SOC-Shield 的 AppImage（x86_64）。
# 用法: bash tooling/build-appimage.sh [--run]
#
# 依赖: flutter build linux 的产物 + appimagetool（脚本自动下载到 .tools/）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${ROOT}/soc_app"
BUNDLE="${APP_DIR}/build/linux/x64/release/bundle"
VERSION="$(sed -n 's/^version: \([^-+]*\).*/\1/p' "${APP_DIR}/pubspec.yaml" | head -1)"
BUILD="${ROOT}/.tools/appimage-build"
OUT="${ROOT}/release"

if [[ ! -x "${BUNDLE}/soc_app" ]]; then
  echo "错误: 未找到 Linux 构建产物，先执行:" >&2
  echo "  source tooling/dev-env.sh && cd soc_app && flutter build linux --release" >&2
  exit 1
fi

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) APPIMAGE_ARCH="x86_64" ;;
  aarch64) APPIMAGE_ARCH="aarch64" ;;
  *) echo "不支持的架构: ${ARCH}" >&2; exit 1 ;;
esac

# --- appimagetool ---
APPIMAGETOOL="${ROOT}/.tools/appimagetool-${APPIMAGE_ARCH}.AppImage"
if [[ ! -x "${APPIMAGETOOL}" ]]; then
  echo "下载 appimagetool..."
  mkdir -p "${ROOT}/.tools"
  curl -L --fail --retry 3 -o "${APPIMAGETOOL}" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage"
  chmod +x "${APPIMAGETOOL}"
fi

# --- AppDir 布局 ---
rm -rf "${BUILD}"
mkdir -p "${BUILD}/AppDir/usr/bin" "${BUILD}/AppDir/usr/share/icons/hicolor/256x256/apps" \
         "${BUILD}/AppDir/usr/share/applications" "${BUILD}/AppDir/usr/lib/soc-app"

cp -r "${BUNDLE}/." "${BUILD}/AppDir/usr/lib/soc-app/"
cat > "${BUILD}/AppDir/usr/bin/soc-shield" <<'LAUNCHER'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$(readlink -f "$0")")/../lib/soc-app" && pwd)"
exec "${HERE}/soc_app" "$@"
LAUNCHER
chmod +x "${BUILD}/AppDir/usr/bin/soc-shield"

# --- 图标：优先用项目 App 图标源图，否则退回占位 ---
ICON_SRC="$(ls "${APP_DIR}/assets/icons/"*.png 2>/dev/null | head -1 || true)"
if [[ -n "${ICON_SRC}" ]]; then
  cp "${ICON_SRC}" "${BUILD}/AppDir/usr/share/icons/hicolor/256x256/apps/soc-shield.png"
  cp "${ICON_SRC}" "${BUILD}/AppDir/soc-shield.png"
else
  echo "警告: 未找到应用图标，使用空白图标占位" >&2
  cp "${ICON_SRC:-/dev/null}" /dev/null 2>/dev/null || true
  : > "${BUILD}/AppDir/usr/share/icons/hicolor/256x256/apps/soc-shield.png"
  cp "${BUILD}/AppDir/usr/share/icons/hicolor/256x256/apps/soc-shield.png" "${BUILD}/AppDir/soc-shield.png"
fi

# --- .desktop ---
cat > "${BUILD}/AppDir/usr/share/applications/soc-shield.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=碳盾 SOC-Shield
Comment=土壤有机碳评估系统 / Soil Organic Carbon Assessment
Exec=soc-shield
Icon=soc-shield
Categories=Science;
Terminal=false
DESKTOP
cp "${BUILD}/AppDir/usr/share/applications/soc-shield.desktop" "${BUILD}/AppDir/soc-shield.desktop"

# --- AppRun（直接指向 launcher，AppImage 自身可被 FUSE 挂载或 --appimage-extract 运行）---
cat > "${BUILD}/AppDir/AppRun" <<'APPRUN'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export APPDIR="${HERE}"
exec "${HERE}/usr/bin/soc-shield" "$@"
APPRUN
chmod +x "${BUILD}/AppDir/AppRun"

# --- 打包 ---
mkdir -p "${OUT}"
APPIMAGETOOL_ARGS=()
if [[ "${APPIMAGE_ARCH}" == "aarch64" ]]; then
  APPIMAGETOOL_ARGS=("--comp" "gzip")
fi
cd "${BUILD}"
if [[ -n "${APPIMAGE_EXTRACT_AND_RUN:-}" || ! -e /dev/fuse ]]; then
  export APPIMAGE_EXTRACT_AND_RUN=1
fi
"${APPIMAGETOOL}" "${APPIMAGETOOL_ARGS[@]}" AppDir \
  "${OUT}/soc-shield-${VERSION}-${APPIMAGE_ARCH}.AppImage"

echo
echo "产物: ${OUT}/soc-shield-${VERSION}-${APPIMAGE_ARCH}.AppImage"
if [[ "${1:-}" == "--run" ]]; then
  exec "${OUT}/soc-shield-${VERSION}-${APPIMAGE_ARCH}.AppImage"
fi
