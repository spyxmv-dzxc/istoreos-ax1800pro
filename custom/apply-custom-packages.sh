#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LIST="$ROOT/custom/packages.txt"
LOG="$ROOT/custom/package-check.log"
: > "$LOG"

# 准备 feeds。即使第三方 feed 有单个包异常，也不要在这里直接中断。
if [ -x ./scripts/feeds ]; then
  ./scripts/feeds update -a >>"$LOG" 2>&1 || true
  ./scripts/feeds install -a >>"$LOG" 2>&1 || true
fi

# 先生成一次当前源码的 package symbol。
make defconfig >/dev/null 2>&1 || true

FOUND=()
MISSING=()
while IFS= read -r pkg; do
  case "$pkg" in ''|\#*) continue;; esac
  if grep -RqsE "^[[:space:]]*config[[:space:]]+PACKAGE_${pkg//./\\.}([[:space:]]|$)" tmp package feeds 2>/dev/null; then
    FOUND+=("$pkg")
    echo "FOUND $pkg" >>"$LOG"
  else
    MISSING+=("$pkg")
    echo "MISSING $pkg" >>"$LOG"
  fi
done < "$LIST"

# 清理本脚本之前写入的配置，再写入当前实际存在的包。
while IFS= read -r pkg; do
  case "$pkg" in ''|\#*) continue;; esac
  sed -i "/^CONFIG_PACKAGE_${pkg//\//\\/}=y$/d" .config 2>/dev/null || true
done < "$LIST"

for pkg in "${FOUND[@]}"; do
  printf 'CONFIG_PACKAGE_%s=y\n' "$pkg" >> .config
done

make defconfig >/dev/null 2>&1 || true

echo "---- package summary ----" >>"$LOG"
echo "FOUND=${#FOUND[@]} MISSING=${#MISSING[@]}" >>"$LOG"
printf '%s\n' "Selected packages:" "${FOUND[@]}" >>"$LOG"
printf '%s\n' "Missing packages:" "${MISSING[@]}" >>"$LOG"
