# 工蜂 · 华为快应用 · 发行与合规仓库

本仓库**不是源码仓库**。工蜂快应用的**全部源码**在 uni-app 工程里：

```
worker-bee-mini-program-1.0        分支 feature/quickapp-huawei
  └── manifest.json 的 "quickapp-webview" / "quickapp-webview-huawei" 节点 = 快应用工程配置
```

本仓库只放**上架与存续所必需、但不属于任何一套源码**的资产：提审资料、隐私政策、广告验收材料、备案信息、签名说明、`.rpk` 产物归档。

## 为什么单独建仓库（而不是往 uni-app 仓库塞）

2026-10-08 实测确认：**uni-app 的「快应用-华为」产物是一个完整的原生快应用工程**（`app.json` + `pages/**/*.qxml`），**没有 `<web>` 壳页、没有 H5**。因此原本设想的"壳工程目录"**并不存在** —— 连 `app.json` 的 `icon` / `features` / `permissions` / `minPlatformVersion` 都由 uni-app 的 `manifest.json` 决定（实测验证过）。

⇒ 快应用工程可以 **100% 由 uni-app 源码仓库重新生成**，无需独立维护。真正需要独立存放的是下面这些**每轮上架都要用、但改源码不会动到**的东西。

## 目录

| 目录 | 内容 |
|---|---|
| `docs/01-发布流程/` | 从编译到上架的完整流程与检查清单 |
| `docs/02-提审资料/` | 商店文案、提审前自查清单 |
| `docs/03-隐私政策/` | 隐私政策（含广告与 OAID 披露）与可发布的静态页 |
| `docs/04-广告验收/` | 鲸鸿动能验收：自检项、《RPK广告位信息表》填写稿、测试广告位 ID |
| `docs/05-备案/` | 快应用 ICP 备案信息（`-4K` 序列） |
| `docs/06-签名/` | 签名证书说明（**密钥不入库**） |
| `scripts/` | 🆕 **macOS 纯命令行构建 `.rpk`**（无需华为快应用 IDE，2026-10-08 实测跑通） |
| `release/` | 各版本上架 `.rpk` 归档 |
| `ad-audit/` | 广告验收材料暂存（内容物不上库，只留说明） |
| `screenshots/` | 商店截图 |

## 关键参数速查

| 项 | 值 |
|---|---|
| 快应用包名 | **`com.genfee.quickapp`**（⚠️ 备案号与包名一一对应，**不可改**） |
| 应用名称 | 工蜂 |
| 编译平台 | `quickapp-webview-huawei`（HBuilderX：发行 → 快应用-华为） |
| 最低平台版本 | `1070`（快应用激励视频要求 ≥1070） |
| 一期广告形态 | 激励视频 + 插屏 |
| 编译产物目录 | `<uni-app工程>/unpackage/dist/build/quickapp-webview/` |

> ⚠️ **不在本仓库**：签名私钥/证书（`sign/`）、`.rpk` 产物以外的构建中间物。

## 相关仓库

| 仓库 | 作用 |
|---|---|
| `worker-bee-mini-program-1.0`（分支 `feature/quickapp-huawei`） | ✅ **快应用源码与全部工程配置** |
| `worker-bee-atomic-service` | 在架鸿蒙元服务（ArkTS 基线，已决定不再维护） |
| `php/genfee` | 后端（`api.ggfee.cn`）；快应用版需要它的 CORS 头配置 |
