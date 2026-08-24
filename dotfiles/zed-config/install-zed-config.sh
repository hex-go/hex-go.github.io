#!/usr/bin/env bash
# install-zed-config.sh
# 在 Linux 机器上运行，安装 Zed keymap/tasks + 速查表脚本。
# 用法:
#   cd 到本目录
#   chmod +x install-zed-config.sh
#   ./install-zed-config.sh

set -e

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function backup() {
  local path="$1"
  if [ -e "$path" ]; then
    local bak="$path.bak-$(date +%Y%m%d-%H%M%S)"
    cp -r "$path" "$bak"
    echo "  备份原文件 -> $bak"
  fi
}

# ---- 1. Zed keymap.json / tasks.json ----------------------------------
zedDir="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
mkdir -p "$zedDir"

for f in keymap.json tasks.json; do
  src="$here/zed/$f"
  dst="$zedDir/$f"
  if [ -f "$src" ]; then
    backup "$dst"
    cp "$src" "$dst"
    echo "[OK] Zed $f -> $dst"
  else
    echo "[跳过] 找不到 $src"
  fi
done

# ---- 2. 速查表脚本 -------------------------------------------------
cheat="$here/wsl/.zed-cheatsheet.sh"
if [ -f "$cheat" ]; then
  dstCheat="$HOME/.zed-cheatsheet.sh"
  backup "$dstCheat"
  cp "$cheat" "$dstCheat"
  chmod +x "$dstCheat"
  # 规范化为 LF 换行
  if command -v dos2unix &> /dev/null; then
    dos2unix -q "$dstCheat"
  else
    sed -i 's/\r$//' "$dstCheat" 2>/dev/null || true
  fi
  echo "[OK] $dstCheat 已安装并设为可执行"
else
  echo "[跳过] 找不到 $cheat"
fi

echo ""
echo "完成。请完全重启 Zed 使 keymap 生效。"
echo "提示: settings.json 未自动覆盖（含代理/路径等机器相关配置）。"
