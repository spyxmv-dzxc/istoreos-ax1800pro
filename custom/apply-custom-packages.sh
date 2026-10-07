#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LIST="$ROOT/custom/packages.txt"
LOG="$ROOT/custom/package-check.log"
: > "$LOG"

# 先让 feeds/package 索引准备好；未知包不阻断整个构建。
if [ -x ./scripts/feeds ]; then
  ./scripts/feeds update -a >>"$LOG" 2>&1 || true
  ./scripts/feeds install -a >>"$LOG" 2>&1 || true
fi

# 生成当前源码可识别的 package symbol 列表。
make defconfig >/dev/null 2>&1 || true

FOUND=()
MISSING=()
while IFS= read -r pkg; do
  case "$pkg" in ''|\#*) continue;; esac
  if grep -RqsE "^[[:space:]]*config[[:space:]]+PACKAGE_${pkg//./\\.}([[:space:]]|$)" tmp 2>/dev/null || \
     grep -RqsE "^[[:space:]]*config[[:space:]]+PACKAGE_${pkg//./\\.}([[:space:]]|$)" package feeds 2>/dev/null; then
    FOUND+=("$pkg")
    echo "FOUND   $pkg" >>"$LOG"
  else
    MISSING+=("$pkg")
    echo "MISSING $pkg" >>"$LOG"
  fi
done < "$LIST"

# 删除我们之前生成的同名配置行，再写入当前能找到的包。
for pkg in "${FOUND[@]}"; do
  sed -i "/^CONFIG_PACKAGE_${pkg//\//\\/}=y$/d" .config 2>/dev/null || true
  printf 'CONFIG_PACKAGE_%s=y\\n' "$pkg" >> .config
 done

# Docker 只编译进去，不强制启用服务。
# iStoreOS/OpenWrt 默认不会因为仅编译 dockerd 就自动启动它。
make defconfig >/dev/null 2>&1 || true

echo "---- package summary ----" >>"$LOG"
echo "FOUND=${#FOUND[@]} MISSING=${#MISSING[@]}" >>"$LOG"
printf '%s\\n' "Selected packages:" "${FOUND[@]}" >>"$LOG"
