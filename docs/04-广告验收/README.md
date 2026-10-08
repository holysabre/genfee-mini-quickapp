# 鲸鸿动能广告验收（快应用 / RPK）

> 来源：参考工程 `mingman-bookkeeping` 的 `huawei-quickapp-ads` 技能（真实项目踩坑沉淀）+ 华为官方文档。**照着做，别跳步。**

---

## 一、测试广告位 ID（**必须用 `test...` 前缀这一套**）

鲸鸿动能客服确认：**快应用（RPK）用 `test...` 前缀家族**。

| 类型 | 测试 ID |
|---|---|
| 原生（大图） | `testu7m3hc4gvm` |
| 原生（视频） | `testy63txaom86` |
| 原生（小图） | `testb65czjivt9` |
| 原生（三图） | `testr6w14o0hqz` |
| **激励视频** | `testx9dtjwj8hp` |
| 横幅 | `testw6vs28auh3` |
| **插屏** | `testb4znbuh3n2` |

> 🔴 另一套（`h8asowxwhq` / `j2mh81xmqs` 等，出自**元服务/HarmonyOS** 文档）在快应用里会**静默返回 `retcode 204`，不报错**，极易误判成"账号准入没走完"。

---

## 二、宿主前提：没有广告源的环境验不出广告

| 环境 | 能验广告 |
|---|---|
| `hap server` 浏览器预览（`localhost:8090/preview`） | ❌ 只有 API 壳 |
| `org.hapjs.mockup`「快应用预览版」 | ❌ 只有 API 壳 |
| ✅ **快应用中心** `com.huawei.fastapp`（应用市场装的走这条） | ✅ |
| ✅ **华为快应用加载器** `com.huawei.fastapp.dev`（IDE 推包走这条） | ✅ |

- ⚠️ **一台手机只能装一种快应用加载器**——装华为加载器前先卸 `org.hapjs.debugger` + `org.hapjs.mockup`
- ⚠️ **加载器与快应用中心存储独立**（可作对照测试手段）
- 🔴 **必须用 release 签名的包**：工具链内置 debug 签名会被判 `1004 media is not exist`
- 深链拉起：`am start -a android.intent.action.VIEW -d 'hap://app/com.genfee.quickapp'` → 选「快应用中心」

---

## 三、关键错误码

| code | 含义 | 处置方向 |
|---|---|---|
| `200` | 请求成功（广告位仍空白 → 应用自身逻辑没显示） | 查自己的显示条件 |
| `204` | 报文正确但**无填充** | ①测试 ID 家族错（非 `test...`）②展示位未放量/尺寸未勾 ③账号准入未完成 |
| `421` / `424` / `703` | 广告位 ID 缺失 / 与包名不匹配 / 快应用广告位 ID 非法 | 展示位 ID 写错或形式不匹配 |
| `425` | 该广告位**不能请求正式广告** | 正式位流程未走完 |
| `498` | **无效广告位，与包名不匹配** | 正式位尚未放量（需先验收 + 运营配置广告） |
| `1004` | `media is not exist`（按「包名 + 签名」查不到媒体） | 后台核包名/签名指纹；**换 release 签名包再测** |
| `1002` | `check appSign failed` | ⚠️ 加载器自身广告位也报这个，**别误读成自己的问题** |

**排查顺序（照这个走，能少绕几小时）**：

```
① 请求根本没发出？（logcat 搜不到 loadAds / slotId）→ 代码侧问题
   · 页面真的调了 create/load 吗
   · manifest 是否声明了 service.ad   ← 本项目已声明，见 docs/01-发布流程
② 421 / 424 / 703 → 展示位 ID 写错、形式与 ID 不匹配
③ 1004 → 展示位在后台不存在，或媒体/签名对不上（用 release 签名包再测）
④ 498 → 展示位存在但正式位未放量
⑤ 204 → a.测试 ID 家族错 b.展示位未放量 c.账号准入未完成
⑥ 一直 204 且 a/b/c 都排除 → 联系客服（附 logcat + 展示位 ID + 请求/响应 JSON + 已自检项）
```

---

## 四、日志：**不在 `HiAdKitLog.log`**

客服给的 `/sdcard/Android/data/com.huawei.hwid/files/Log/HiAdKitLog.log` **查不到宿主内快应用的 slotId**（加载器自带的 `HiAdSDKLog.log` 也一样）。**真实日志在 `logcat`**：

| tag | 作用 |
|---|---|
| `AGDSDK-NativeAd` | 原生广告加载器 |
| `HiAdSDK.RewardAdLoader` | 激励视频加载 |
| `HiAdSDK.n` | 统一回调层（`loadAds` / `onAdFailed, errorCode:N`） |
| `HiAdKit.HiAdRequestDataLogger` | **完整请求 JSON**（`slotid`/`pkgname`/`oaid`） |
| `HiAdKit.HiAdResponseDataLogger` | **完整响应 JSON**（素材 / `retcode` / `retcode30`） |
| `FastAPP` | 快应用宿主层 |

两条判据：**①请求体 `slotid`/`pkgname` 是不是自己的；②响应 `retcode` 与 `multiad[].retcode30`**。

抓取：
```bash
adb logcat -c          # 先清
# … 触发广告（请求 → 展示 → 点击；激励视频看完至发奖）…
adb logcat -d | Out-File -Encoding utf8 out.txt    # PowerShell 必须显式 utf8，否则 UTF-16
```

---

## 五、快应用自检项（**缺一项会被验收打回**）

| 类型 | 自检条目 | 本项目实现要点 |
|---|---|---|
| 通用 | 调用广告请求前必须展示用户隐私协议 | `App.vue` 启动 `ensureAdConsent()` + `detail.vue` 兜底；未同意不创建实例、不发请求 |
| 通用 | 只允许广告区域可点击跳转落地页 | 广告卡片根节点不可点（一期无原生广告，二期注意） |
| 通用 | 请求失败禁止频繁重试（**只能重试 1 次**） | 失败即隐藏/提示，不做循环重试 |
| 通用 | 禁止设置定时器循环请求广告 | 定时器只用于 UI 兜底（倒计时文案），不用于请求 |
| 通用 | 一次请求的广告不能重复展示 | 展示后重新 `create` |
| 通用 | 实时请求展示；预缓存注意 **1 小时有效窗口** | 激励视频 `load`→`show` 不超 1 小时 |
| 激励视频 | 无广告返回时不显示入口或给合理文案 | 失败 → 按钮文案回退，不留"加载中"死按钮 |
| 激励视频 | 入口防快速点击 | `adLoading` 状态位拦截二次点击 |
| 原生 | （二期）素材/广告标识/来源/标题 ≥22 汉字/关闭按钮/下载按钮 | 一期不涉及 |
| 原生 | （二期）上报曝光与展示事件 | 一期不涉及 |
| 原生 | （二期）关闭按钮 ≥32dp×32dp 且与底色有区分 | 一期不涉及 |
| 原生 | （二期）`startDownload` 仅点击下载按钮时调用 | 一期不涉及 |

> 一期只接入 **激励视频 + 插屏**，原生/Banner 填「不涉及」。

---

## 六、验收交付流程

```
自测通过
 → 联系鲸鸿动能客服，提交「《RPK广告位信息表》+ 自测 SDK 日志」压缩包（群发）
 → 鲸鸿动能验收（2~3 个工作日，群里同步）
 → 运营配置广告（需提供：媒体包名 + 展示形式 + 正式展示位 ID）
 → 代码把测试 ID 换回正式 ID → versionName/versionCode 各 +1 → 重新打包上架
 → 线上开始正常下发广告
```

- 模板下载：`https://developer.huawei.com/consumer/cn/doc/distribution/monetize/fujianxiazai-0000001132177051`
  → 取**《RPK广告位信息表》**（不是 APK 那份，也不是 HarmonyOS NEXT 那份）
- 压缩包命名：**`<appid>+<应用名>+<公司名>.zip`**
- 日志按「每个样式一份」命名：`<样式>_HiAdKitLog.log`（内容从 logcat 提取，文件首行注明来源）
- 若需邮箱发应用包：**用 163 邮箱，勿用网盘 / QQ 邮箱**

填写稿见 [`RPK广告位信息表-填写稿.md`](./RPK广告位信息表-填写稿.md)。
