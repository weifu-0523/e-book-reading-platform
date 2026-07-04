# M3a — 排版基线增强实施计划（任务 2/4/5/7）

> **Spec**: `docs/superpowers/specs/2026-07-03-m3a-typography-baseline-design.md`
> **Predecessor**: M2.11 (commit c4cc169)
> **Branch**: master
> **Verification**: `flutter.bat analyze` + `flutter test --concurrency=1` + Debug exe 实跑

## 实施顺序（依赖排序）

任务 7（默认值）→ 任务 5（字体）→ 任务 2（缩进）→ 任务 4（末页对齐）。
理由：默认值最独立先做；字体需下载资源（耗时，可与代码并行）；缩进和末页都改
`epubx_renderer.dart` 的 buildSinglePage，放最后集中改减少冲突。

---

## T1 — 任务 7：默认值调整

### T1.1 改 `TypographySettings.defaults()`
- 文件：`reader_engine/lib/core/typography_settings.dart:62-68`
- 改动：
  - `fontSize: 16.0` → `18.0`
  - `lineHeight: 1.5` → `1.8`
  - `pageMargin: PageMargin.normal` → `PageMargin.wide`
- fontFamily/theme 保持不变。
- **验收**：`typography_settings_test.dart` 默认值断言更新并通过。

### T1.2 检查默认值引用点
- grep `TypographySettings.defaults` 全仓，确认没有其他地方硬编码旧值（16/1.5/normal）。
- 排版面板档位标签不变（仅默认选中态随 defaults 变）。

---

## T2 — 任务 5：字体选项改常用名 + 打包开源字体

### T2.1 下载开源字体到 `app/assets/fonts/`
- 创建 `app/assets/fonts/` 目录。
- 下载（用 WebFetch 或 curl，OFL 协议）：
  - `NotoSansSC-Regular.otf`（思源黑体）— Google Noto GitHub
  - `NotoSerifSC-Regular.otf`（思源宋体）— Google Noto GitHub
  - `LXGWWenKai-Regular.ttf`（霞鹜文楷）— LXGW GitHub
  - 圆体：先尝试找开源圆体；若无，本里程碑先用前 3 款 + 系统，圆体标"暂未提供"
- 每款下载后核对文件大小（~8-16MB）和格式（.otf/.ttf）。

### T2.2 pubspec.yaml 声明字体
- 文件：`app/pubspec.yaml`
- 在 `flutter:` 段加：
  ```yaml
  fonts:
    - family: NotoSansSC
      fonts:
        - asset: assets/fonts/NotoSansSC-Regular.otf
    - family: NotoSerifSC
      fonts:
        - asset: assets/fonts/NotoSerifSC-Regular.otf
    - family: LXGWWenKai
      fonts:
        - asset: assets/fonts/LXGWWenKai-Regular.ttf
  ```
- 跑 `flutter pub get` 让 Flutter 注册字体。

### T2.3 .gitignore 忽略字体大文件
- 文件：`app/.gitignore`（或根 `.gitignore`）
- 加：`app/assets/fonts/*.otf`、`app/assets/fonts/*.ttf`
- **但保留** `app/assets/fonts/README.md`（说明字体来源 + 下载脚本）入 git。

### T2.4 字体下载脚本
- 新建 `scripts/download-fonts.sh`（Git Bash 可跑）+ `scripts/download-fonts.ps1`（PowerShell）
- 脚本内容：mkdir fonts → curl 各字体下载链接 → 校验文件存在。
- README 增补："首次拉取后跑 `bash scripts/download-fonts.sh` 获取字体资源"。

### T2.5 改字体选项 UI
- 文件：`app/lib/features/reader/widgets/typography_panel.dart:121-126`
- 改 ChoiceChip 列表：
  ```dart
  [
    ('系统', null),
    ('黑体', 'NotoSansSC'),
    ('宋体', 'NotoSerifSC'),
    ('楷体', 'LXGWWenKai'),
    // 圆体视实际打包情况
    ...userFonts.map((f) => (f.displayName, f.familyName)),
  ]
  ```
- **验收**：`typography_panel_test.dart`（若存在）断言 4-5 个字体选项；
  选中黑体后 current.fontFamily == 'NotoSansSC'。

### T2.6 实测体积
- `flutter build windows --debug` 实测 exe 增量。
- 若 >80MB 增量，决策：减款 / subset / 接受。写入 CHANGELOG。

---

## T3 — 任务 2：段落首行缩进

### T3.1 TypographySettings 加缩进字段
- 文件：`reader_engine/lib/core/typography_settings.dart`
- 加字段：
  ```dart
  final double paragraphIndentEm;   // 默认 2.0
  final bool paragraphIndentEnabled; // 默认 true
  ```
- 更新构造函数、copyWith、toJson、fromJson、defaults、equality。
- **验收**：`typography_settings_test.dart` 缩进字段往返测试。

### T3.2 新建 TypographyStyleInjector
- 文件：`reader_engine_epub_view/lib/typography_style_injector.dart`（新）
- 实现 spec D1 的 inject 方法。
- **验收**：`typography_style_injector_test.dart`（新）。

### T3.3 scroll 模式接入
- 文件：`reader_engine_epub_view/lib/epubx_renderer.dart:847`
- `currentHighlightedHtml()` 返回前调 `TypographyStyleInjector.inject(html, ...)`。
- 用 `_typography.paragraphIndentEm` + `_typography.paragraphIndentEnabled`。

### T3.4 paged 模式接入
- 文件：`reader_engine_epub_view/lib/epubx_renderer.dart:943-952`
- `buildSinglePage` 内，highlight inject 后、HtmlWidget 前调 inject。

### T3.5 排版面板加缩进开关
- 文件：`app/lib/features/reader/widgets/typography_panel.dart`
- 在「字体」一节后加「段落」一节：Switch（首行缩进）+ 档位（2em 默认）。
- onChanged 走现有 copyWith 链。

---

## T4 — 任务 4：末页顶部对齐强化

### T4.1 buildSinglePage 加 Align
- 文件：`reader_engine_epub_view/lib/epubx_renderer.dart:963-972`
- 改为：
  ```dart
  return SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.all(margin),
        child: HtmlWidget(pageHtml, textStyle: style.copyWith(color: fg)),
      ),
    ),
  );
  ```

### T4.2 widget inspector 复核（实跑）
- 重建 Debug exe，翻到任意章节末页。
- 用 Flutter inspector（或运行时 debugPrint 布局尺寸）确认文字是否顶部对齐。
- 若 Align 后仍居中 → 根因在 HtmlWidget 内部，需进一步查 0.15.3 Block 行为
  （可能需 customWidgetBuilder 包一层）。
- 把根因结论写入 CHANGELOG。

### T4.3 测试
- `epubx_renderer_test.dart`：buildSinglePage widget tree 含 Align（alignment topCenter）。

---

## T5 — 收尾

### T5.1 analyze + test
- `source activate ebook && flutter.bat analyze`（CJK 路径）
- `flutter test --concurrency=1`（reader_engine_epub_view + app reader 相关）
- 修复所有回归。

### T5.2 重建 exe
- `flutter build windows --debug`
- 路径：`app/build/windows/x64/runner/Debug/zhiyue.exe`

### T5.3 CHANGELOG + commit
- `CHANGELOG.md` 加 M3a 条目（含 4 子任务 + 字体体积实测 + 末页根因结论）。
- git add（含 spec/plan/源码/测试，**不含字体大文件**已被 gitignore）。
- commit message：`feat(reader): M3a 排版基线增强 — 默认值/段落缩进/末页对齐/常用字体`
- push origin master。

## 验收标准（整体）

- [ ] 新打开的书首屏：字号 18、行距宽松、页边距宽松
- [ ] 段落首行缩进 2em（可关闭）
- [ ] 章节末页文字从顶部排起，不居中
- [ ] 字体可选：系统/黑体/宋体/楷体（/圆体），切换后中文正确渲染
- [ ] analyze 0 error，测试全过
- [ ] exe 体积增量记录在 CHANGELOG
- [ ] 字体下载脚本可跑，README 有说明

## 回滚点

- T1（默认值）：单文件改动，`git revert` 即可。
- T2（字体）：pubspec + .gitignore + UI，回滚需删 fonts 目录 + 撤 pubspec 段。
- T3（缩进）：新文件 + 接入点，回滚删文件 + 撤 2 处 inject 调用。
- T4（末页对齐）：单 buildSinglePage 改动，回滚撤 Align。
- 每个任务独立 commit（或合并为一个 M3a commit），便于精准回滚。
