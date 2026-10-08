#!/usr/bin/env bash
# =============================================================================
# 从华为快应用 IDE 的 Windows 安装包中，在 macOS 上提取「快应用构建工具链」
#
# 背景：华为快应用 IDE 已无 macOS 版（官方下载页只提供 Windows），
#       但其构建内核 fa-toolkit 及其依赖 @hw-quickapp/* 未在 npm 公开发布，
#       只随 IDE 安装包分发。
#
#       实测（2026-10-08）：该安装包内的工具链**自带 darwin 预编译二进制**
#       （@hw-quickapp/fa-aaptjs/lib/bin/x64/darwin/aapt），IDE 自身代码里也有
#       darwin 分支（chownDarwinAapt / if (process.platform === 'darwin')），
#       因此可在 macOS 上直接运行。
#
# 依赖：innoextract（brew install innoextract）
#
# 用法：
#   ./extract-toolchain-macos.sh [输出目录]        # 默认 /tmp/qa-toolchain
#
# 产物：<输出目录>/node_modules    ← 供 build-rpk-macos.sh 使用
# =============================================================================
set -euo pipefail

OUT_DIR="${1:-/tmp/qa-toolchain}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 官方安装包（winget 清单 Huawei.QuickAppIde 14.0.1 记录，含 SHA256 可校验）
# ⚠️ 该 URL 带签名与有效期；失效时到 https://developer.huawei.com/consumer/cn/doc/Tools-Library/quickapp-ide-download-0000001101172926
#    取最新 Windows 安装包，并从 microsoft/winget-pkgs 的 installer.yaml 取新 SHA256。
INSTALLER_URL='https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_package_901_9/5e/v3/aFdD1fSZSOOrRtqsWG14Pw/QuickAppIDE-V14.0.1-Win64.exe?HW-CC-KV=V1&HW-CC-Date=20240306T073107Z&HW-CC-Expire=315360000&HW-CC-Sign=0422592C5622FEA1EAE520EDEDBBBB2BBEB95053B96178BC1FB66481C85174E9'
EXPECTED_SHA256='D5BAB8E3A1A91E8940297208BC7B65E149370F4CD9FBCC8AB9193640829B23CB'
EXE="$WORK/QuickAppIDE.exe"

command -v innoextract >/dev/null || { echo "❌ 缺少 innoextract：brew install innoextract"; exit 1; }

echo "==> 1/4 下载官方安装包（约 185MB）"
curl -fsSL --max-time 1800 -o "$EXE" "$INSTALLER_URL"

echo "==> 2/4 校验 SHA256"
ACTUAL="$(shasum -a 256 "$EXE" | awk '{print toupper($1)}')"
[ "$ACTUAL" = "$EXPECTED_SHA256" ] || { echo "❌ SHA256 不匹配！实际=$ACTUAL"; exit 1; }
echo "    ✅ $ACTUAL"

echo "==> 3/4 解出 deveco-debug 扩展（快应用工具链所在）"
mkdir -p "$WORK/x"
innoextract -e -s -I "app/resources/app/extensions/deveco-debug" -d "$WORK/x" "$EXE"
SRC="$WORK/x/app/resources/app/extensions/deveco-debug"
[ -d "$SRC/node_modules" ] || { echo "❌ 未找到工具链目录"; exit 1; }

echo "==> 4/4 组装到 $OUT_DIR"
mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR/node_modules"
cp -R "$SRC/node_modules" "$OUT_DIR/node_modules"

# fa-toolkit 必须可被 node 解析到；顺带把 darwin aapt 置为可执行
chmod 755 "$OUT_DIR/node_modules/@hw-quickapp/fa-aaptjs/lib/bin/x64/darwin/aapt" 2>/dev/null || true

echo
echo "✅ 完成：$OUT_DIR/node_modules  ($(du -sh "$OUT_DIR/node_modules" | cut -f1))"
echo "   含 fa-toolkit $(node -p "require('$OUT_DIR/node_modules/fa-toolkit/package.json').version" 2>/dev/null || echo '?')"
echo
echo "下一步： ./build-rpk-macos.sh <快应用工程目录> $OUT_DIR"
