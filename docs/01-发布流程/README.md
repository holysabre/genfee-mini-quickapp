# 发布流程与检查清单

> 目标：从改完源码到线上出广告，一次性走通，不返工。
> 依据：2026-10-08 实测 + 参考工程 `mingman-bookkeeping` 的 `huawei-quickapp-ads` 技能。

---

## 阶段 0 · 前置（一次性，可并行启动）

| # | 事项 | 说明 | 状态 |
|---|---|---|---|
| 1 | **快应用 ICP 备案** | 华为云「新增互联网信息」，资源类型选**「备案授权码」**（域名不在华为云）。⏱ **5–25 个工作日**，全线最长工期项 | ☐ |
| 2 | AGC 创建**快应用**应用拿 APPID | 备案时要填，且**必须与上架时的 APPID 一致** | ☐ |
| 3 | 申请鲸鸿动能**快应用媒体 + 展示位** | 媒体需登记 **RPK 包名 + release 签名指纹**，否则报 `1004` | ☐ |
| 4 | 安装**华为快应用 IDE** | 真机调试与构建 `.rpk` 用 | ☐ |
| 5 | 发行范围确认 | 已确认**只发华为**（不发快应用联盟 vivo/oppo） | ✅ |

---

## 阶段 1 · 编译

在 **uni-app 工程**（`worker-bee-mini-program-1.0`，分支 `feature/quickapp-huawei`）里：

### 方式 A：HBuilderX GUI（常规）

```
发行 → 快应用-华为
→ unpackage/dist/build/quickapp-webview/
```

### 方式 B：命令行（本机可跑，CI 友好）

```bash
C=/Applications/HBuilderX.app/Contents/HBuilderX/plugins/uniapp-cli-vite
HXR=/Applications/HBuilderX.app/Contents/HBuilderX
PRJ=<uni-app 工程根>

# 项目是 HBuilderX 工程，本来没有这两个东西，编译前临时补上
ln -sfn "$C/node_modules" "$PRJ/node_modules"
printf '{"name":"worker-bee-mini-program","version":"1.0.13","private":true,"dependencies":{}}' > "$PRJ/package.json"

cd "$PRJ" && env \
  HX_APP_ROOT="$HXR" HX_Version=5.26 RUN_BY_HBUILDERX=true \
  UNI_INPUT_DIR="$PRJ" UNI_OUTPUT_DIR=/tmp/qa-out \
  UNI_PLATFORM=quickapp-webview-huawei UNI_SUB_PLATFORM=quickapp-webview-huawei \
  UNI_CLI_CONTEXT="$C" \
  node "$C/node_modules/@dcloudio/vite-plugin-uni/bin/uni.js" build -p quickapp-webview-huawei

# ⚠️⚠️ 必须删掉，否则污染工程
rm -f "$PRJ/node_modules" "$PRJ/package.json"
```

看到 `DONE Build complete.` 即成功（产物约 400KB）。

> 四个环境开关少一个就失败：`HX_APP_ROOT`（漏了就找不到 sass/vue）、`HX_Version`/`RUN_BY_HBUILDERX`、`UNI_SUB_PLATFORM`（漏了不生成 `quickapp.config.json`）。

### 编译后必查（30 秒）

```bash
cat /tmp/qa-out/app.json
```

必须满足：

- [ ] `package` = `com.genfee.quickapp`
- [ ] `versionCode` 已**递增**（同版本号无法覆盖发布）
- [ ] `minPlatformVersion` = `1070`
- [ ] `icon` 是**工程内相对路径**（`/static/...`），**不能是 `/Users/...` 绝对路径**
- [ ] `features` 含 **`service.ad`**（缺了真机拿不到广告 API）与 `system.fetch`
- [ ] `appType` = `webapp`

---

### 方式 C：🆕 **在 macOS 上纯命令行构建 `.rpk`（无需华为快应用 IDE）** ⭐

> **为什么需要这条**：华为快应用 IDE **已无 macOS 版**（官方下载页只提供 Windows）。但其构建内核 `fa-toolkit` 随 IDE 安装包分发、且**自带 darwin 预编译二进制**，可在 macOS 上直接运行。**2026-10-08 已实测跑通并产出合格 `.rpk`。**

```bash
cd <本仓库>/scripts

# ① 一次性：从官方 Windows 安装包提取工具链（约 185MB 下载，含 SHA256 校验）
#    需要 innoextract：brew install innoextract
./extract-toolchain-macos.sh /tmp/qa-toolchain

# ② 每次发版：构建 .rpk
./build-rpk-macos.sh <uni-app 快应用产物目录> /tmp/qa-toolchain debug     # 真机链路验证
./build-rpk-macos.sh <uni-app 快应用产物目录> /tmp/qa-toolchain release   # 上架（需正式证书）
```

产物：`<产物目录>/.quickapp/dist/com.genfee.quickapp[.release].rpk`

**实测结果（2026-10-08，debug）**：249 KB，合法 zip，43 个文件，含
`manifest.json` / `META-INF/CERT`（签名 4.5KB）/ `pages/**/*.html` + `.pack.js`；
`manifest.json` 内 `package=com.genfee.quickapp`、`features` 含 `service.ad`、
`minPlatformVersion=1070` 全部正确。

**四个必须点**（少一个就会失败，均已实测）：

| # | 要点 | 说明 |
|---|---|---|
| 1 | `<工程>/node_modules` 必须有 `fa-toolkit` + `webpack` | 工具链 ~317MB，脚本用软链，不复制 |
| 2 | `<工程>/package.json` 必须存在 | `fa-toolkit` 会 `require(<工程>/package.json)` |
| 3 | 跑 node 前 **`env -u NODE_OPTIONS`** | 某些宿主会经 `NODE_OPTIONS` 注入 fs 代理，导致 `mkdirSync` 抛 `EEXIST` 假错 |
| 4 | `QUICK_APP=<含 debugkey/> 的目录>` | `fa-toolkit` 的 `getDefDebugKey()` 从这里读调试证书 |

**签名说明**：
- 仅**真机链路验证** → 脚本可用内置调试证书，产物 `manifest.json` 里是 `versionType:debug / debug:true`，**可用于加载器调试，不能上架**。
- **上架** → 必须把**工蜂自己的**快应用证书放进 `<工程>/sign/{certificate.pem,private.pem}`，并用 `versionType=release`。
  ⚠️ 参考工程曾因 `FORMAL_*` 常量没被引用而**线上跑的是测试广告位 ID**——上架前务必核对。

**合规提醒**：工具链提取自华为官方发布的 Windows 安装包（SHA256 已校验），属**绕过官方分发渠道的变通做法**；对外发布/团队协作前建议确认许可与内部规范。

---

## 阶段 2 · 构建 `.rpk`（华为快应用 IDE，Windows）

> ⚠️ 无 Windows 环境时请用上面的**方式 C**。

1. 华为快应用 IDE 导入上一步产物目录
2. 配置 **release 签名**（见 `docs/06-签名/`）
3. 「构建」→ 产出 `.rpk`
4. 归档到本仓库 `release/`，命名：`com.genfee.quickapp.release.<versionName>.<versionCode>.rpk`

⚠️ `--disable-sign` 出的 `nosign` 包只能验证链路，**不能上架**。

---

## 阶段 3 · 真机自测（广告，见 `docs/04-广告验收/`）

- [ ] 用 **release 签名包**（debug 签名必报 `1004 media is not exist`）
- [ ] 用**华为快应用加载器**（`com.huawei.fastapp.dev`）或**快应用中心**（`com.huawei.fastapp`）打开
      —— `hap server` 浏览器预览 与 `org.hapjs.mockup` 预览版**没有广告源**，验广告必然空白
- [ ] 广告位用 **`test...` 前缀**的测试 ID
- [ ] 关闭系统「限制广告跟踪」
- [ ] 完整走：请求 → 展示 → 点击 → 导出日志；激励视频**完整观看至发奖**

---

## 阶段 4 · 上架前代码切换（**最容易漏**）

- [ ] `utils/ads.js`：把 `NATIVE_AD_ID` / `REWARDED_AD_ID`（或等价的正式位常量）**换成正式展示位 ID**
      ⚠️ 参考工程就是栽在这里：`FORMAL_*` 常量定义了却**没被引用**，线上包内仍是测试 ID ⇒ **线上不出广告**
- [ ] `manifest.json` 的 `quickapp-webview.versionName` / `versionCode` 各 **+1**
- [ ] 华为云备案号已在应用**显著位置**展示（未标识会被驳回 / 已上架被下架）
- [ ] 鲸鸿动能后台：媒体状态「启用」+ 应用市场状态「已上架」（正式 ID 生效前提）

---

## 阶段 5 · 提审

按 `docs/02-提审资料/release-checklist.md` 逐项自查后，在 AGC 上传 `.rpk` 并填写：

应用分类标签 / 内容分级 / 隐私声明 / 备案信息。

---

## 附：后端联动

快应用通过快应用引擎的原生网络栈请求 `api.ggfee.cn`，**不经浏览器同源策略**（`uni.request` → `qa.request`）。
但后端仍已为 `mini/*` 加了 CORS 头（`php/genfee` 的 `config/cors.php`），作为保险 —— 部署时：

- [ ] 部署 `config/cors.php`
- [ ] 🔴 **线上若跑过 `php artisan config:cache`，必须重跑**（否则改动不生效）：
      `php artisan config:clear && php artisan config:cache`
- [ ] 复验：`curl -sI -H 'Origin: https://x.com' https://api.ggfee.cn/mini/settings/global | grep -i access-control` → 应出现 `*`
- [ ] 接口返回的图片是明文 `http://`（`image.ggfee.cn` / `dev.oss.ggfee.cn`），客户端适配层已统一转 `https://`
