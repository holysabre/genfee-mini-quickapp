# .rpk 产物归档

各版本上架用 release 签名 `.rpk` 放这里，便于追溯线上包内容。

命名规范：

```
com.genfee.quickapp.release.<versionName>.<versionCode>.rpk
例：com.genfee.quickapp.release.1.0.0.1.rpk
```

⚠️ 归档前请确认：

- [ ] 是 **release 签名**包（不是 debug / nosign）
- [ ] **广告位已换成正式 ID**（不是 `test...` 测试 ID）—— 否则线上不出广告
- [ ] `versionCode` 已递增
- [ ] 已在 AGC 成功上传并通过审核

| 版本 | versionCode | 归档日期 | 审核状态 | 备注 |
|---|---|---|---|---|
| — | — | — | — | 尚未发布 |
