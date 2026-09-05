#!/usr/bin/env bash
# 把 docs/user-guide 的说明书 Markdown 同步为应用 assets（构建期源）。
# Markdown 是唯一维护源；assets/manual/ 下的是同步产物，不手改。
# 用法: bash tooling/sync-manual.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/docs/user-guide"
DEST="${ROOT}/soc_app/assets/manual"

mkdir -p "${DEST}"
for f in quick-start.md user-guide.md scientific-basis.md faq.md glossary.md changelog.md; do
  if [[ ! -f "${SRC}/${f}" ]]; then
    echo "缺少说明书源文件: ${SRC}/${f}" >&2
    exit 1
  fi
  # 应用内不渲染封面元数据占位符；原样同步即可，占位符只出现在 cover.md。
  cp "${SRC}/${f}" "${DEST}/${f}"
done
echo "说明书已同步到 ${DEST}:"
ls -1 "${DEST}"
