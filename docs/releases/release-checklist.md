# Release Checklist — 待办与已完成

本文档跟踪 release 相关任务的完成状态。每次发版前对照检查。

## 待办（需用户/Claude 配合）

### v1.0.0 Gitee Release 页面

- **状态**：❌ **未创建**（tag 已推送，但 Gitee 上没有 release 页面）
- **执行**：浏览器开 https://gitee.com/weifu0523/e-book-reading-platform/releases/new，选 tag `v1.0.0`
- **Release notes**：复制 CHANGELOG.md `[1.0.0]` 段落
- **附 artifact**：
  - 需重新 build v1.0.0 tag（`git checkout v1.0.0` 后跑 release-procedure 步骤 3-7）
  - 上传 setup.exe / portable.zip / .apk
  - 上传 4 张截图（其中 3 张需先补齐，见下）

### v1.1.0-alpha Gitee Release 页面

- **状态**：❌ **未创建**
- **Release notes 草稿**：见 [`release-notes-v1.1.0-alpha.md`](./release-notes-v1.1.0-alpha.md)
- **执行**：同上，选 tag `v1.1.0-alpha`

### 截图补齐（3/4 缺失）

| 文件 | 状态 | 捕获步骤 |
|---|---|---|
| `docs/screenshots/epub_reader.png` | ✅ M8 T14 完成 | — |
| `docs/screenshots/library.png` | ❌ | 启动 app → 显示 library 页面（含 ≥2 本书） → Win+Shift+S 截屏 |
| `docs/screenshots/pdf_reader.png` | ❌ | 打开 PDF 书 → 显示 reader（page indicator 或 chapter drawer 可见） → 截屏 |
| `docs/screenshots/notes.png` | ❌ | 打开有高亮的书的 Notes 页 → 截屏 |

详见 [`docs/screenshots/README.md`](../screenshots/README.md)。

### 性能 baseline 测量

- **状态**：❌ **未做**
- **背景**：phase 2 roadmap §6 把"冷启动 < 2s / 5MB EPUB ≥ 55fps"列为入口判定硬标准
- **执行**：用 DevTools timeline + performance overlay 测三组数据，记入 `docs/maintainers-runbook.md` §9.4 backfill

## 已完成

### v1.1.0-alpha release 准备

- ✅ tag `m2.1-complete` + `v1.1.0-alpha` 已推送
- ✅ `CHANGELOG.md` 1.1.0-alpha 段落完整
- ✅ `README.md` 已同步到 v1.1.0-alpha 状态（2026-07-01, commit `26a4a59`）
- ✅ `docs/release-procedure.md` 已同步 v1.0.0+ 流程（2026-07-01, commit `2dd609a`）
- ✅ AGPLv3 源文件版权头已补齐（2026-07-01, commit `5a70f2c`，203 文件）
- ✅ Release notes 草稿已准备（本目录 `release-notes-v1.1.0-alpha.md`）
- ✅ 项目级 review 已生成（`docs/reviews/2026-07-01-project-review.md`）

### v1.0.0 release 准备

- ✅ tag `v1.0.0` 已推送
- ✅ `CHANGELOG.md` 1.0.0 段落完整
- ✅ Maintainer's runbook 836 行
- ✅ Project review 已生成

## 执行顺序建议

1. **手动跑 release-procedure 步骤 1-7**（约 1-2 小时）build v1.1.0-alpha artifact
2. **手动捕获 3 张截图**（约 15 分钟）
3. **手动创建 Gitee Release v1.1.0-alpha 页面**（约 10 分钟，使用草稿）
4. **手动 build + 创建 v1.0.0 Gitee Release 页面**（如果需要 stable 入口；约 1-2 小时）
5. **手动跑性能 baseline**（约 30 分钟）记入 runbook §9.4

总计：约 3-4 小时手动工作。Claude 无法替代这些步骤。
