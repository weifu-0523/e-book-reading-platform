#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# M3a/任务5：下载打包开源 OFL 字体到 app/assets/fonts/。
#
# 字体文件不入 git（体积大，见 app/.gitignore）。首次拉取仓库后跑本脚本获取字体，
# 否则排版面板的"黑体/宋体/楷体"选项会 fallback 到系统字体（不崩，但中文渲染非预期）。
#
# 用法（Git Bash / WSL）：
#   bash scripts/download-fonts.sh
#
# 字体来源（均为 SIL Open Font License 1.1）：
#   NotoSansSC  思源黑体 — notofonts/noto-cjk SubsetOTF/SC（~8MB）
#   NotoSerifSC 思源宋体 — notofonts/noto-cjk SubsetOTF/SC（~12MB）
#   LXGWWenKai  霞鹜文楷 — lxgw/LxgwWenKai release v1.522（~25MB）
#
# 网络说明：脚本默认用国内可访问的镜像（jsDelivr + gh-proxy.com）。若任一镜像失效，
# 修改下方 URL 常量即可。直连 GitHub（github.com / raw.githubusercontent.com）在
# 大陆通常被墙，故默认不走直连。

set -euo pipefail

# 解析仓库根目录（脚本在 scripts/ 下，根目录是其父目录）。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FONT_DIR="$ROOT_DIR/app/assets/fonts"

mkdir -p "$FONT_DIR"

# 下载单文件的辅助函数：依次尝试多个镜像，第一个成功即停。
download() {
  local out="$1"; shift
  local urls=("$@")
  for url in "${urls[@]}"; do
    echo "  try: $url"
    if curl -fSL --max-time 180 -o "$out" "$url"; then
      echo "  OK ($(stat -c%s "$out" 2>/dev/null || echo '?') bytes)"
      return 0
    fi
    rm -f "$out"
  done
  echo "  FAILED: all mirrors returned error"
  return 1
}

echo "== M3a 字体下载 → $FONT_DIR =="

echo "[1/3] NotoSansSC-Regular.otf（思源黑体）"
download "$FONT_DIR/NotoSansSC-Regular.otf" \
  "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf" \
  "https://gh-proxy.com/https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf"

echo "[2/3] NotoSerifSC-Regular.otf（思源宋体）"
download "$FONT_DIR/NotoSerifSC-Regular.otf" \
  "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf" \
  "https://gh-proxy.com/https://github.com/notofonts/noto-cjk/raw/main/Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf"

echo "[3/3] LXGWWenKai-Regular.ttf（霞鹜文楷）"
download "$FONT_DIR/LXGWWenKai-Regular.ttf" \
  "https://gh-proxy.com/https://github.com/lxgw/LxgwWenKai/releases/download/v1.522/LXGWWenKai-Regular.ttf" \
  "https://ghfast.top/https://github.com/lxgw/LxgwWenKai/releases/download/v1.522/LXGWWenKai-Regular.ttf" \
  "https://github.com/lxgw/LxgwWenKai/releases/download/v1.522/LXGWWenKai-Regular.ttf"

echo "== 校验 =="
ok=0; fail=0
for f in NotoSansSC-Regular.otf NotoSerifSC-Regular.otf LXGWWenKai-Regular.ttf; do
  if [ -s "$FONT_DIR/$f" ]; then
    echo "  ✓ $f ($(stat -c%s "$FONT_DIR/$f") bytes)"
    ok=$((ok+1))
  else
    echo "  ✗ $f 缺失"
    fail=$((fail+1))
  fi
done
echo ""
echo "完成：$ok 成功 / $fail 失败"
if [ "$fail" -gt 0 ]; then
  echo "警告：部分字体下载失败，对应选项将 fallback 到系统字体。请检查网络或手工下载。"
  exit 1
fi
echo "下载完成后在 app/ 目录跑 flutter pub get 让 Flutter 注册字体。"
