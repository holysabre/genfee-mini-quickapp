#!/usr/bin/env bash
# =============================================================================
# 在 macOS 上把 uni-app 的「快应用-华为」产物打成 .rpk（无需华为快应用 IDE）
#
# 实测背景（2026-10-08）：华为快应用 IDE 无 macOS 版，但其构建内核 fa-toolkit
# 可在 macOS 上运行，且其 `lib/webpack.config.js` 会识别 uni-app 的 webapp 产物
# （存在 quickapp.config.json 且 <quickappRoot>/app.json 存在 → 走 web.webpack.config），
# 自动完成 app.json → 快应用 manifest.json 的转换并打包签名。
#
# 前置：
#   1. 已用 extract-toolchain-macos.sh 提取工具链（或指到任意含 fa-toolkit+webpack 的 node_modules）
#   2. 快应用工程目录 = uni-app「发行 → 快应用-华为」的产物（含 app.json / quickapp.config.json）
#   3. 签名：<工程>/sign/ 下放 certificate.pem + private.pem
#      · 仅做真机链路验证 → 可用内置调试证书（见 --debugkey 说明）
#      · 上架 → 必须换成**工蜂自己的**快应用证书，且 versionType=release
#
# 用法：
#   ./build-rpk-macos.sh <快应用工程目录> <工具链目录> [debug|release]
#
# 例：
#   ./build-rpk-macos.sh /tmp/qa-out /tmp/qa-toolchain debug
#
# 产物： <工程>/.quickapp/dist/com.genfee.quickapp[.release].rpk
# =============================================================================
set -euo pipefail

PROJ="${1:?用法: build-rpk-macos.sh <快应用工程目录> <工具链目录> [debug|release]}"
TOOLCHAIN="${2:?缺少工具链目录（含 node_modules/fa-toolkit）}"
VTYPE="${3:-debug}"

PROJ="$(cd "$PROJ" && pwd)"
TOOLCHAIN="$(cd "$TOOLCHAIN" && pwd)"
NM_SRC="$TOOLCHAIN/node_modules"

[ -d "$NM_SRC/fa-toolkit" ] || { echo "❌ $NM_SRC/fa-toolkit 不存在；先跑 extract-toolchain-macos.sh"; exit 1; }
[ -f "$PROJ/app.json" ]     || { echo "❌ $PROJ/app.json 不存在（不是快应用 webapp 产物？）"; exit 1; }

echo "==> 1/5 准备工程侧依赖"
# 工具链体积 ~317MB，用软链避免复制；若已存在实体目录则不动
if [ ! -e "$PROJ/node_modules" ]; then
  ln -s "$NM_SRC" "$PROJ/node_modules"
  echo "    已软链 node_modules -> $NM_SRC"
else
  echo "    已存在 $PROJ/node_modules，保持不动"
fi

# compiler 会 require(<工程>/package.json)
[ -f "$PROJ/package.json" ] || printf '{"name":"genfee-quickapp","version":"1.0.0","private":true}\n' > "$PROJ/package.json"

echo "==> 2/5 确认 quickapp.config.json（signRoot 必须指向签名目录）"
python3 - "$PROJ" <<'PY'
import json, os, sys
p = os.path.join(sys.argv[1], 'quickapp.config.json')
d = json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}
d.setdefault('quickappRoot', './')
d.setdefault('packOptions', {'ignore': []})
d['signRoot'] = d.get('signRoot') or 'sign'
json.dump(d, open(p, 'w', encoding='utf-8'))
print('    ', json.dumps(d, ensure_ascii=False))
PY

echo "==> 3/5 检查签名证书"
if [ ! -f "$PROJ/sign/certificate.pem" ] || [ ! -f "$PROJ/sign/private.pem" ]; then
  echo "    ⚠️  $PROJ/sign/{certificate.pem,private.pem} 缺失"
  echo "        上架：必须放工蜂自己的快应用证书"
  echo "        仅链路验证：可从 hap-toolkit 内置调试证书复制："
  echo "          cp <...>/@hap-toolkit/packager/lib/signature/pem/{certificate,private}.pem $PROJ/sign/"
  [ "$VTYPE" = "release" ] && { echo "❌ release 无证书不可继续"; exit 1; }
fi

echo "==> 4/5 构建（versionType=$VTYPE）"
rm -rf "$PROJ/.quickapp"
cd "$PROJ"
# ⚠️ 两个必须点：
#   1) -u NODE_OPTIONS：某些宿主/IDE 会通过 NODE_OPTIONS 注入 fs 代理，
#      会让 fa-toolkit 的 mkdirSync 抛 EEXIST 假错（实测）
#   2) QUICK_APP=<含 debugkey/> 的目录：fa-toolkit 的 getDefDebugKey() 从这里读调试证书
env -u NODE_OPTIONS \
  projectRoot="$PROJ" \
  versionType="$VTYPE" \
  ${QUICK_APP:+QUICK_APP="$QUICK_APP"} \
  node node_modules/webpack/bin/webpack.js \
       --config ./node_modules/fa-toolkit/webpack.config.js

echo "==> 5/5 产物"
RPK=$(find "$PROJ/.quickapp/dist" -name "*.rpk" 2>/dev/null | head -1)
[ -n "$RPK" ] || { echo "❌ 未生成 .rpk，请检查上方日志"; exit 1; }
echo "    ✅ $RPK  ($(du -h "$RPK" | cut -f1))"

echo
echo "后续："
echo "  真机： adb push \"$RPK\" /sdcard/Download/  →  华为快应用加载器「+」→ 选文件安装"
echo "  自检： 解压后应含 manifest.json / META-INF/CERT / pages/**"
