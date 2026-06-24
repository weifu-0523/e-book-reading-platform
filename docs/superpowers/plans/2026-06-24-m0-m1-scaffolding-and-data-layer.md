# M0 + M1 实现计划：项目脚手架 + 数据层基础

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建 Flutter 项目骨架（M0），实现完整的本地数据层（M1）—— drift SQLite schema、领域模型、Repository 抽象、文件存储 —— 全部带单元测试覆盖。

**Architecture:** 本地优先（local-first）数据层。drift 作为 SQLite ORM，每张表配一个 DAO；Repository 接口抽象所有数据访问，让 MVP 2.0 的同步层可零改造包装。文件系统走 FileStorage 抽象层，书库按 file_hash 去重存储。

**Tech Stack:**
- Flutter 3.27+ / Dart 3.5+
- drift 2.x（SQLite ORM，含 FTS5）
- Riverpod 2.x（最小化使用，M0+M1 阶段仅做 Provider 注册）
- build_runner（drift 代码生成）
- test / drift_dev（测试）

**对应 spec 章节：** [2026-06-24-ebook-platform-design.md](../specs/2026-06-24-ebook-platform-design.md) §2（架构）、§5（数据层）

---

## 文件结构总览

完成 M0+M1 后，目录结构如下：

```
e-book-reading-platform/                    # 项目根 (= 当前 H:\projiect\电子书阅读平台)
├── .gitignore                              # 已存在
├── LICENSE                                 # 已存在 (AGPLv3)
├── README.md                               # 已存在
├── docs/                                   # 已存在
├── app/                                    # 【新建】Flutter 主项目
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   ├── lib/
│   │   ├── main.dart                       # 入口
│   │   ├── core/
│   │   │   ├── app.dart                    # MaterialApp 根
│   │   │   ├── app_providers.dart          # Riverpod 容器
│   │   │   ├── theme.dart                  # Material 3 主题（基础）
│   │   │   └── locator.dart                # Locator sealed class
│   │   ├── data/
│   │   │   ├── local/
│   │   │   │   ├── database.dart           # drift Database 定义
│   │   │   │   ├── database.g.dart         # drift 生成
│   │   │   │   ├── tables/
│   │   │   │   │   ├── books.dart
│   │   │   │   │   ├── book_notes.dart
│   │   │   │   │   ├── annotations.dart
│   │   │   │   │   ├── reading_progress.dart
│   │   │   │   │   ├── typography_profiles.dart
│   │   │   │   │   ├── book_typography_overrides.dart
│   │   │   │   │   └── settings.dart
│   │   │   │   ├── daos/
│   │   │   │   │   ├── books_dao.dart
│   │   │   │   │   ├── book_notes_dao.dart
│   │   │   │   │   ├── annotations_dao.dart
│   │   │   │   │   ├── reading_progress_dao.dart
│   │   │   │   │   ├── typography_dao.dart
│   │   │   │   │   └── settings_dao.dart
│   │   │   │   ├── connections/
│   │   │   │   │   └── database_connection.dart   # NativeDatabase 工厂
│   │   │   │   └── file_storage.dart              # 文件系统抽象
│   │   │   ├── models/
│   │   │   │   ├── book.dart
│   │   │   │   ├── book_note.dart
│   │   │   │   ├── annotation.dart
│   │   │   │   ├── reading_progress.dart
│   │   │   │   ├── typography_profile.dart
│   │   │   │   ├── typography_settings.dart
│   │   │   │   ├── highlight.dart
│   │   │   │   └── search_result.dart
│   │   │   └── repositories/
│   │   │       ├── book_repository.dart           # 抽象接口
│   │   │       ├── local_book_repository.dart     # 本地实现
│   │   │       ├── reading_progress_repository.dart
│   │   │       ├── local_reading_progress_repository.dart
│   │   │       ├── notes_repository.dart
│   │   │       ├── local_notes_repository.dart
│   │   │       ├── settings_repository.dart
│   │   │       └── local_settings_repository.dart
│   │   ├── services/
│   │   │   └── book_import_service.dart           # 书籍导入（hash + dedup）
│   │   └── features/
│   │       └── home/
│   │           └── home_page.dart                 # M0 占位页
│   ├── assets/
│   │   └── .gitkeep
│   ├── test/
│   │   ├── core/
│   │   │   └── locator_test.dart
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── book_test.dart
│   │   │   │   ├── book_note_test.dart
│   │   │   │   ├── annotation_test.dart
│   │   │   │   ├── reading_progress_test.dart
│   │   │   │   └── typography_settings_test.dart
│   │   │   ├── local/
│   │   │   │   ├── database_test.dart
│   │   │   │   ├── daos/
│   │   │   │   │   ├── books_dao_test.dart
│   │   │   │   │   ├── book_notes_dao_test.dart
│   │   │   │   │   ├── annotations_dao_test.dart
│   │   │   │   │   ├── reading_progress_dao_test.dart
│   │   │   │   │   ├── typography_dao_test.dart
│   │   │   │   │   └── settings_dao_test.dart
│   │   │   │   └── file_storage_test.dart
│   │   │   ├── repositories/
│   │   │   │   ├── book_repository_test.dart
│   │   │   │   ├── reading_progress_repository_test.dart
│   │   │   │   ├── notes_repository_test.dart
│   │   │   │   └── settings_repository_test.dart
│   │   │   └── services/
│   │   │       └── book_import_service_test.dart
│   │   ├── helpers/
│   │   │   └── drift_test_helper.dart             # 测试用内存 DB 工厂
│   │   └── widget_test.dart                       # M0 widget 测试
│   └── integration_test/
│       └── app_smoke_test.dart                    # 冒烟测试
└── .github/
    └── workflows/
        └── ci.yml                                 # CI（也用于 Gitee 镜像触发）
```

---

## Phase A：项目脚手架（M0）

### Task 1：环境验证与 Flutter 项目初始化

**Files:**
- Create: `app/pubspec.yaml`（由 flutter create 生成后修改）
- Create: `app/lib/main.dart`（由 flutter create 生成后简化）
- Create: `app/README.md`（flutter create 自动生成，可删）
- Create: `app/.gitignore`（flutter create 自动生成）

- [ ] **Step 1：验证 Flutter 环境**

Run:
```bash
flutter --version
dart --version
```

Expected: Flutter 3.27+ / Dart 3.5+。若未安装，按 https://docs.flutter.dev/get-started/install 安装。Windows 端还需要 Visual Studio with C++ desktop workload（用于 Windows 桌面构建）。

- [ ] **Step 2：在项目根创建 Flutter 项目（手动指定路径，避免 flutter create 在当前目录污染）**

Run（在 `H:\projiect\电子书阅读平台` 下执行）:
```bash
flutter create --project-name zhiyue --org dev.zhiyue --platforms=windows,android app
```

Expected: 在 `app/` 子目录生成 Flutter 项目骨架。

- [ ] **Step 3：进入 app 目录验证项目可运行**

Run:
```bash
cd app
flutter pub get
flutter analyze
```

Expected: `flutter analyze` 输出 `No issues found!`。

- [ ] **Step 4：提交（首次代码入库）**

Run（在项目根目录）:
```bash
cd ..
git add app/
git commit -m "feat(m0): flutter 项目脚手架初始化

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

Expected: commit + push 成功。

---

### Task 2：依赖与 lint 配置

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/analysis_options.yaml`

- [ ] **Step 1：替换 `app/pubspec.yaml` 全部内容**

```yaml
name: zhiyue
description: 智阅 - 面向深度阅读/学习者的开源 Flutter 电子书阅读平台
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.5.0
  flutter: ^3.27.0

dependencies:
  flutter:
    sdk: flutter

  # 状态管理
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # 路由
  go_router: ^14.2.0

  # 数据库
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24

  # 文件系统
  path: ^1.9.0
  path_provider: ^2.1.4
  file_picker: ^8.1.2

  # 工具
  uuid: ^4.4.2
  collection: ^1.18.0
  crypto: ^3.0.5
  meta: ^1.15.0

  # i18n
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  # 代码生成
  build_runner: ^2.4.11
  drift_dev: ^2.18.0
  riverpod_generator: ^2.4.3
  custom_lint: ^0.6.4
  riverpod_lint: ^2.3.13

  # 静态分析
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  generate: true
```

- [ ] **Step 2：创建 `app/analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    prefer_single_quotes: true
    require_trailing_commas: true
    avoid_print: true
    unawaited_futures: true
    cascade_invocations: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
```

- [ ] **Step 3：拉依赖并验证**

Run:
```bash
cd app
flutter pub get
flutter analyze
```

Expected: 依赖安装成功，`flutter analyze` 无错误。

- [ ] **Step 4：提交**

```bash
cd ..
git add app/pubspec.yaml app/pubspec.lock app/analysis_options.yaml
git commit -m "feat(m0): 配置项目依赖与 lint 规则

- Riverpod / go_router / drift / 文件系统
- flutter_lints + riverpod_lint
- require_trailing_commas / prefer_single_quotes

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 3：项目目录结构与最小可运行 App

**Files:**
- Create: `app/lib/core/app.dart`
- Create: `app/lib/core/app_providers.dart`
- Create: `app/lib/core/theme.dart`
- Create: `app/lib/features/home/home_page.dart`
- Modify: `app/lib/main.dart`
- Create: `app/assets/.gitkeep`

- [ ] **Step 1：创建目录结构**

Run（在 `app/` 下）:
```bash
mkdir -p lib/core lib/data/local/tables lib/data/local/daos lib/data/local/connections lib/data/models lib/data/repositories lib/services lib/features/home
mkdir -p assets test/core test/data/models test/data/local/daos test/data/repositories test/data/services test/helpers
mkdir -p integration_test
touch assets/.gitkeep
```

- [ ] **Step 2：创建 `app/lib/core/theme.dart`**

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5C6BC0),
      brightness: Brightness.light,
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5C6BC0),
      brightness: Brightness.dark,
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
```

- [ ] **Step 3：创建 `app/lib/core/app_providers.dart`（Riverpod 容器，M0+M1 仅占位）**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局 ProviderContainer 工厂。
/// M0 阶段无具体 Provider；M1 起逐步添加数据库 / repository providers。
final providers = <Override>[];
```

- [ ] **Step 4：创建 `app/lib/features/home/home_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('智阅')),
      body: const Center(
        child: Text('M0 + M1 数据层脚手架'),
      ),
    );
  }
}
```

- [ ] **Step 5：创建 `app/lib/core/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_page.dart';
import 'theme.dart';

class ZhiYueApp extends ConsumerWidget {
  const ZhiYueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '智阅',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomePage(),
    );
  }
}
```

- [ ] **Step 6：替换 `app/lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app.dart';
import 'core/app_providers.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: providers,
      child: const ZhiYueApp(),
    ),
  );
}
```

- [ ] **Step 7：验证 analyze + 测试运行（不含具体测试，只跑默认 counter test）**

Run:
```bash
cd app
flutter analyze
flutter test
```

Expected: analyze 无错误；默认 `widget_test.dart` 可能因 main.dart 改变而失败 —— 在下一步删除它。

- [ ] **Step 8：删除 flutter create 生成的默认 widget_test.dart**

Run:
```bash
rm test/widget_test.dart
```

- [ ] **Step 9：提交**

```bash
cd ..
git add app/
git commit -m "feat(m0): 项目目录结构与最小可运行 App

- core/ + data/ + features/ + services/ 分层
- Material 3 主题（日/夜）
- Riverpod ProviderScope 注入
- 占位 HomePage

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 4：M0 验证 widget 测试

**Files:**
- Create: `app/test/widget_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/widget_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/app.dart';

void main() {
  testWidgets('App boots and shows HomePage', (tester) async {
    await tester.pumpWidget(const ZhiYueApp());
    await tester.pumpAndSettle();

    expect(find.text('智阅'), findsOneWidget);
    expect(find.text('M0 + M1 数据层脚手架'), findsOneWidget);
  });
}
```

- [ ] **Step 2：运行测试验证通过**

Run:
```bash
cd app
flutter test test/widget_test.dart
```

Expected: 1 test passed.

- [ ] **Step 3：提交**

```bash
cd ..
git add app/test/widget_test.dart
git commit -m "test(m0): 启动 widget 测试

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 5：CI 配置（GitHub Actions，可触发 Gitee 镜像）

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1：创建 `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Show Flutter version
        run: flutter --version

      - name: Install dependencies
        run: flutter pub get

      - name: Verify formatting
        run: dart format --set-exit-if-changed lib/ test/

      - name: Analyze project
        run: flutter analyze

      - name: Run code generation (drift)
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Run tests
        run: flutter test --coverage
```

> 说明：本项目主仓库在 Gitee，但 CI 配置写在 GitHub Actions 格式。Gitee 也有兼容 CI（Gitee Go），如未来需要可同步配置。当前 CI 仅作本地参考，Gitee 不一定启用。

- [ ] **Step 2：验证本地 analyze + format 通过**

Run:
```bash
cd app
dart format lib/ test/
flutter analyze
cd ..
```

Expected: format 无 diff，analyze 无错误。

- [ ] **Step 3：提交**

```bash
git add .github/
git commit -m "ci: 添加 GitHub Actions 工作流

- format / analyze / build_runner / test
- Gitee 仓库镜像参考用

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase B：领域模型（M1.1）

### Task 6：Locator 抽象（EPUB CFI / PDF 坐标统一）

**Files:**
- Create: `app/lib/core/locator.dart`
- Test: `app/test/core/locator_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/core/locator_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';

void main() {
  group('EpubCfiLocator', () {
    test('serializes to JSON correctly', () {
      final locator = EpubCfiLocator(
        cfi: 'epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)',
        chapterIndex: 0,
        chapterTitle: '第一章',
      );
      expect(locator.toJson(), {
        'type': 'epubCfi',
        'cfi': 'epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)',
        'chapterIndex': 0,
        'chapterTitle': '第一章',
      });
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'type': 'epubCfi',
        'cfi': 'epubcfi(/6/4!/4/2)',
        'chapterIndex': 2,
        'chapterTitle': '附录',
      };
      final locator = Locator.fromJson(json) as EpubCfiLocator;
      expect(locator.cfi, 'epubcfi(/6/4!/4/2)');
      expect(locator.chapterIndex, 2);
      expect(locator.chapterTitle, '附录');
    });
  });

  group('PdfPageLocator', () {
    test('serializes to JSON correctly', () {
      final locator = PdfPageLocator(page: 42, offsetX: 100.5, offsetY: 200.0);
      expect(locator.toJson(), {
        'type': 'pdfPage',
        'page': 42,
        'offsetX': 100.5,
        'offsetY': 200.0,
      });
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'type': 'pdfPage',
        'page': 7,
        'offsetX': 0.0,
        'offsetY': 0.0,
      };
      final locator = Locator.fromJson(json) as PdfPageLocator;
      expect(locator.page, 7);
    });
  });

  test('Locator.fromJson throws on unknown type', () {
    expect(() => Locator.fromJson({'type': 'unknown'}), throwsArgumentError);
  });

  test('round-trip serialization preserves data', () {
    final original = EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0);
    final restored = Locator.fromJson(original.toJson());
    expect(restored, original);
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/core/locator_test.dart
```

Expected: FAIL with "locator.dart not found" / "Locator not defined"。

- [ ] **Step 3：实现 `app/lib/core/locator.dart`**

```dart
import 'package:meta/meta.dart';

/// 阅读位置的统一抽象。
///
/// EPUB 使用 CFI（Canonical Fragment Identifier）；
/// PDF 使用页码 + 视口偏移。
@immutable
sealed class Locator {
  const Locator();

  Map<String, dynamic> toJson();

  factory Locator.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'epubCfi':
        return EpubCfiLocator(
          cfi: json['cfi'] as String,
          chapterIndex: json['chapterIndex'] as int,
          chapterTitle: json['chapterTitle'] as String?,
        );
      case 'pdfPage':
        return PdfPageLocator(
          page: json['page'] as int,
          offsetX: (json['offsetX'] as num).toDouble(),
          offsetY: (json['offsetY'] as num).toDouble(),
        );
      default:
        throw ArgumentError.value(type, 'type', 'Unknown Locator type');
    }
  }

  String toJsonString();
}

class EpubCfiLocator extends Locator {
  final String cfi;
  final int chapterIndex;
  final String? chapterTitle;

  const EpubCfiLocator({
    required this.cfi,
    required this.chapterIndex,
    this.chapterTitle,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'epubCfi',
        'cfi': cfi,
        'chapterIndex': chapterIndex,
        if (chapterTitle != null) 'chapterTitle': chapterTitle,
      };

  @override
  String toJsonString() => cfi;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpubCfiLocator &&
          cfi == other.cfi &&
          chapterIndex == other.chapterIndex &&
          chapterTitle == other.chapterTitle;

  @override
  int get hashCode => Object.hash(cfi, chapterIndex, chapterTitle);
}

class PdfPageLocator extends Locator {
  final int page;
  final double offsetX;
  final double offsetY;

  const PdfPageLocator({
    required this.page,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pdfPage',
        'page': page,
        'offsetX': offsetX,
        'offsetY': offsetY,
      };

  @override
  String toJsonString() => 'page:$page';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPageLocator &&
          page == other.page &&
          offsetX == other.offsetX &&
          offsetY == other.offsetY;

  @override
  int get hashCode => Object.hash(page, offsetX, offsetY);
}
```

- [ ] **Step 4：运行测试验证通过**

Run:
```bash
flutter test test/core/locator_test.dart
```

Expected: All tests passed.

- [ ] **Step 5：提交**

```bash
cd ..
git add app/lib/core/locator.dart app/test/core/locator_test.dart
git commit -m "feat(m1): Locator 抽象（EPUB CFI + PDF 页码）

跨格式统一的阅读位置抽象，为 MVP 2.0 同步预留序列化基础。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 7：Book 模型

**Files:**
- Create: `app/lib/data/models/book.dart`
- Test: `app/test/data/models/book_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/models/book_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';

void main() {
  group('Book', () {
    test('creates instance with required fields', () {
      final book = Book(
        id: 'b1',
        title: '与天为敌',
        author: '彼得·伯恩斯坦',
        format: BookFormat.epub,
        filePath: '/library/abc.epub',
        fileHash: 'abc123',
        fileSizeBytes: 1024,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      expect(book.title, '与天为敌');
      expect(book.format, BookFormat.epub);
    });

    test('copyWith updates only specified fields', () {
      final book = Book(
        id: 'b1',
        title: 't',
        author: null,
        format: BookFormat.epub,
        filePath: 'p',
        fileHash: 'h',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      final updated = book.copyWith(lastReadAt: DateTime(2026, 6, 25));
      expect(updated.lastReadAt, DateTime(2026, 6, 25));
      expect(updated.title, 't'); // 未变
    });

    test('equality by id', () {
      final b1 = Book(
        id: 'x',
        title: 'a',
        author: null,
        format: BookFormat.pdf,
        filePath: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      final b2 = Book(
        id: 'x',
        title: 'b',
        author: null,
        format: BookFormat.pdf,
        filePath: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      expect(b1, b2); // 仅 id 相等即视为相等
    });
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/models/book_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/models/book.dart`**

```dart
import 'package:meta/meta.dart';

enum BookFormat { epub, pdf }

@immutable
class Book {
  final String id;
  final String title;
  final String? author;
  final BookFormat format;
  final String filePath;
  final String fileHash;
  final int fileSizeBytes;
  final String? coverPath;

  final DateTime addedAt;
  final DateTime? lastReadAt;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.filePath,
    required this.fileHash,
    required this.fileSizeBytes,
    required this.coverPath,
    required this.addedAt,
    required this.lastReadAt,
  });

  Book copyWith({
    String? title,
    String? author,
    String? coverPath,
    DateTime? lastReadAt,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format,
      filePath: filePath,
      fileHash: fileHash,
      fileSizeBytes: fileSizeBytes,
      coverPath: coverPath ?? this.coverPath,
      addedAt: addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Book && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4：运行测试验证通过**

Run:
```bash
flutter test test/data/models/book_test.dart
```

Expected: All passed.

- [ ] **Step 5：提交**

```bash
cd ..
git add app/lib/data/models/book.dart app/test/data/models/book_test.dart
git commit -m "feat(m1): Book 领域模型

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 8：Annotation 模型（高亮 + 笔记）

**Files:**
- Create: `app/lib/data/models/annotation.dart`
- Test: `app/test/data/models/annotation_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/models/annotation_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';

void main() {
  group('Annotation', () {
    test('is a highlight when note is null', () {
      final a = Annotation(
        id: 'a1',
        bookNoteId: 'bn1',
        locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        quote: '风险即未来的不确定性',
        note: null,
        color: HighlightColor.yellow,
        tags: const [],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 24),
        updatedAt: DateTime(2026, 6, 24),
      );
      expect(a.isHighlightOnly, isTrue);
      expect(a.hasNote, isFalse);
    });

    test('is a note when note is non-null', () {
      final a = Annotation(
        id: 'a1',
        bookNoteId: 'bn1',
        locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        quote: '风险即未来的不确定性',
        note: '我的思考：...',
        color: HighlightColor.green,
        tags: const ['风险管理'],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 24),
        updatedAt: DateTime(2026, 6, 24),
      );
      expect(a.isHighlightOnly, isFalse);
      expect(a.hasNote, isTrue);
    });

    test('tags are unmodifiable', () {
      final a = Annotation(
        id: 'a1',
        bookNoteId: 'bn1',
        locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        quote: '',
        note: null,
        color: HighlightColor.yellow,
        tags: const ['t1'],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 24),
        updatedAt: DateTime(2026, 6, 24),
      );
      expect(() => a.tags.add('t2'), throwsUnsupportedError);
    });
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/models/annotation_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/models/annotation.dart`**

```dart
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../core/locator.dart';

enum HighlightColor { yellow, green, blue, red, purple }

enum AnnotationSource { manual, aiAssisted }

@immutable
class Annotation {
  final String id;
  final String bookNoteId;
  final Locator locator;
  final String quote;
  final String? note;
  final HighlightColor color;
  final List<String> tags;
  final AnnotationSource source;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Annotation({
    required this.id,
    required this.bookNoteId,
    required this.locator,
    required this.quote,
    required this.note,
    required this.color,
    required this.tags,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isHighlightOnly => note == null;
  bool get hasNote => note != null && note!.isNotEmpty;

  Annotation copyWith({
    String? note,
    HighlightColor? color,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id,
      bookNoteId: bookNoteId,
      locator: locator,
      quote: quote,
      note: note ?? this.note,
      color: color ?? this.color,
      tags: tags ?? this.tags,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 防御性：返回不可修改的 List 视图。
  List<String> get tags => UnmodifiableListView(tags);
}
```

> 注意：Dart 不允许字段与 getter 同名。修正版见 Step 3b。

- [ ] **Step 3b：修正字段/getter 冲突**

Replace `app/lib/data/models/annotation.dart` Step 3 中 `tags` 字段与 getter 的冲突。最终版本：

```dart
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../core/locator.dart';

enum HighlightColor { yellow, green, blue, red, purple }

enum AnnotationSource { manual, aiAssisted }

@immutable
class Annotation {
  final String id;
  final String bookNoteId;
  final Locator locator;
  final String quote;
  final String? note;
  final HighlightColor color;
  final List<String> _tags;
  final AnnotationSource source;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Annotation({
    required this.id,
    required this.bookNoteId,
    required this.locator,
    required this.quote,
    required this.note,
    required this.color,
    required List<String> tags,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  }) : _tags = tags;

  bool get isHighlightOnly => note == null;
  bool get hasNote => note != null && note!.isNotEmpty;

  List<String> get tags => UnmodifiableListView(_tags);

  Annotation copyWith({
    String? note,
    HighlightColor? color,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id,
      bookNoteId: bookNoteId,
      locator: locator,
      quote: quote,
      note: note ?? this.note,
      color: color ?? this.color,
      tags: tags ?? _tags,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 4：运行测试验证通过**

Run:
```bash
flutter test test/data/models/annotation_test.dart
```

Expected: All passed.

- [ ] **Step 5：提交**

```bash
cd ..
git add app/lib/data/models/annotation.dart app/test/data/models/annotation_test.dart
git commit -m "feat(m1): Annotation 模型（高亮+笔记）

5 色高亮、自定义标签、不可变 tags 视图。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 9：BookNote 模型

**Files:**
- Create: `app/lib/data/models/book_note.dart`
- Test: `app/test/data/models/book_note_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/models/book_note_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book_note.dart';

void main() {
  group('BookNote', () {
    test('creates empty note', () {
      final note = BookNote.empty(
        id: 'bn1',
        bookId: 'b1',
        bookTitle: '与天为敌',
      );
      expect(note.title, '《与天为敌》读书笔记');
      expect(note.summary, '');
      expect(note.keyTakeaways, isEmpty);
      expect(note.annotations, isEmpty);
    });

    test('copyWith replaces keyTakeaways immutably', () {
      final note = BookNote.empty(id: 'bn1', bookId: 'b1', bookTitle: 't');
      final updated = note.copyWith(
        keyTakeaways: const ['点 1', '点 2'],
      );
      expect(updated.keyTakeaways, ['点 1', '点 2']);
      expect(note.keyTakeaways, isEmpty); // 原对象不变
    });
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/models/book_note_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/models/book_note.dart`**

```dart
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'annotation.dart';

@immutable
class BookNote {
  final String id;
  final String bookId;
  final String title;
  final String summary;
  final List<String> keyTakeaways;
  final List<Annotation> annotations;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BookNote({
    required this.id,
    required this.bookId,
    required this.title,
    required this.summary,
    required List<String> keyTakeaways,
    required List<Annotation> annotations,
    required this.createdAt,
    required this.updatedAt,
  })  : keyTakeaways = keyTakeaways,
        annotations = annotations;

  factory BookNote.empty({
    required String id,
    required String bookId,
    required String bookTitle,
  }) {
    final now = DateTime.now();
    return BookNote(
      id: id,
      bookId: bookId,
      title: '《$bookTitle》读书笔记',
      summary: '',
      keyTakeaways: const [],
      annotations: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  BookNote copyWith({
    String? title,
    String? summary,
    List<String>? keyTakeaways,
    List<Annotation>? annotations,
    DateTime? updatedAt,
  }) {
    return BookNote(
      id: id,
      bookId: bookId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
      annotations: annotations ?? this.annotations,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<String> get keyTakeaways => UnmodifiableListView(
        // ignore: prefer_initializing_formals
        (this as _BookNoteInternal)._keyTakeaways,
      );
}
```

> 注意：上面 `_BookNoteInternal` 的写法不正确。改用与 Annotation 相同的私有字段模式。最终版本见 Step 3b。

- [ ] **Step 3b：重写 `app/lib/data/models/book_note.dart`（标准私有字段写法）**

```dart
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'annotation.dart';

@immutable
class BookNote {
  final String id;
  final String bookId;
  final String title;
  final String summary;
  final List<String> _keyTakeaways;
  final List<Annotation> _annotations;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BookNote({
    required this.id,
    required this.bookId,
    required this.title,
    required this.summary,
    required List<String> keyTakeaways,
    required List<Annotation> annotations,
    required this.createdAt,
    required this.updatedAt,
  })  : _keyTakeaways = keyTakeaways,
        _annotations = annotations;

  factory BookNote.empty({
    required String id,
    required String bookId,
    required String bookTitle,
  }) {
    final now = DateTime.now();
    return BookNote(
      id: id,
      bookId: bookId,
      title: '《$bookTitle》读书笔记',
      summary: '',
      keyTakeaways: const [],
      annotations: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  List<String> get keyTakeaways => UnmodifiableListView(_keyTakeaways);
  List<Annotation> get annotations => UnmodifiableListView(_annotations);

  BookNote copyWith({
    String? title,
    String? summary,
    List<String>? keyTakeaways,
    List<Annotation>? annotations,
    DateTime? updatedAt,
  }) {
    return BookNote(
      id: id,
      bookId: bookId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      keyTakeaways: keyTakeaways ?? _keyTakeaways,
      annotations: annotations ?? _annotations,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 4：运行测试验证通过**

Run:
```bash
flutter test test/data/models/book_note_test.dart
```

Expected: All passed.

- [ ] **Step 5：提交**

```bash
cd ..
git add app/lib/data/models/book_note.dart app/test/data/models/book_note_test.dart
git commit -m "feat(m1): BookNote 模型（一书一笔记）

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 10：ReadingProgress + TypographySettings + SearchResult 模型

**Files:**
- Create: `app/lib/data/models/reading_progress.dart`
- Create: `app/lib/data/models/typography_settings.dart`
- Create: `app/lib/data/models/search_result.dart`
- Create: `app/lib/data/models/typography_profile.dart`
- Test: `app/test/data/models/reading_progress_test.dart`
- Test: `app/test/data/models/typography_settings_test.dart`

- [ ] **Step 1：写 ReadingProgress 测试**

Create `app/test/data/models/reading_progress_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/reading_progress.dart';

void main() {
  test('ReadingProgress holds locator and percent', () {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 0.42,
      updatedAt: DateTime(2026, 6, 24),
    );
    expect(p.bookId, 'b1');
    expect(p.percent, 0.42);
  });

  test('percent clamped between 0 and 1', () {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 1.5,
      updatedAt: DateTime(2026, 6, 24),
    );
    expect(p.percent, 1.0);
  });
}
```

- [ ] **Step 2：实现 `app/lib/data/models/reading_progress.dart`**

```dart
import 'package:meta/meta.dart';

import '../../core/locator.dart';

@immutable
class ReadingProgress {
  final String bookId;
  final Locator locator;
  final double _percent;
  final DateTime updatedAt;

  ReadingProgress({
    required this.bookId,
    required this.locator,
    required double percent,
    required this.updatedAt,
  }) : _percent = percent.clamp(0.0, 1.0);

  double get percent => _percent;
}
```

- [ ] **Step 3：写 TypographySettings 测试**

Create `app/test/data/models/typography_settings_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/typography_settings.dart';

void main() {
  test('default settings have expected values', () {
    final s = TypographySettings.defaults();
    expect(s.fontSize, 16.0);
    expect(s.lineHeight, 1.5);
    expect(s.theme, ReadingTheme.light);
    expect(s.fontFamily, isNotNull);
  });

  test('copyWith updates specific fields', () {
    final s = TypographySettings.defaults();
    final updated = s.copyWith(fontSize: 20.0, theme: ReadingTheme.dark);
    expect(updated.fontSize, 20.0);
    expect(updated.theme, ReadingTheme.dark);
    expect(updated.lineHeight, 1.5); // 未变
  });

  test('equality', () {
    final s1 = TypographySettings.defaults();
    final s2 = TypographySettings.defaults();
    expect(s1, s2);
  });
}
```

- [ ] **Step 4：实现 `app/lib/data/models/typography_settings.dart`**

```dart
import 'package:meta/meta.dart';

enum ReadingTheme { light, dark, sepia, eInk }

enum PageMargin { compact, normal, wide }

@immutable
class TypographySettings {
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final ReadingTheme theme;
  final PageMargin pageMargin;

  const TypographySettings({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.theme,
    required this.pageMargin,
  });

  factory TypographySettings.defaults() => const TypographySettings(
        fontSize: 16.0,
        lineHeight: 1.5,
        fontFamily: null, // null = 系统字体
        theme: ReadingTheme.light,
        pageMargin: PageMargin.normal,
      );

  TypographySettings copyWith({
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    ReadingTheme? theme,
    PageMargin? pageMargin,
  }) {
    return TypographySettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      theme: theme ?? this.theme,
      pageMargin: pageMargin ?? this.pageMargin,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographySettings &&
          fontSize == other.fontSize &&
          lineHeight == other.lineHeight &&
          fontFamily == other.fontFamily &&
          theme == other.theme &&
          pageMargin == other.pageMargin;

  @override
  int get hashCode =>
      Object.hash(fontSize, lineHeight, fontFamily, theme, pageMargin);
}
```

- [ ] **Step 5：创建 `app/lib/data/models/search_result.dart`（无独立测试，使用类即用）**

```dart
import 'package:meta/meta.dart';

import '../../core/locator.dart';

@immutable
class SearchResult {
  final String bookId;
  final String bookTitle;
  final Locator locator;
  final String snippet;
  final int matchCount;

  const SearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.locator,
    required this.snippet,
    required this.matchCount,
  });
}
```

- [ ] **Step 6：创建 `app/lib/data/models/typography_profile.dart`**

```dart
import 'package:meta/meta.dart';

import 'typography_settings.dart';

@immutable
class TypographyProfile {
  final String id;
  final String name;
  final TypographySettings settings;
  final bool isDefault;

  const TypographyProfile({
    required this.id,
    required this.name,
    required this.settings,
    required this.isDefault,
  });

  TypographyProfile copyWith({
    String? name,
    TypographySettings? settings,
    bool? isDefault,
  }) {
    return TypographyProfile(
      id: id,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
```

- [ ] **Step 7：运行所有模型测试**

Run:
```bash
cd app
flutter test test/data/models/
```

Expected: All passed.

- [ ] **Step 8：提交**

```bash
cd ..
git add app/lib/data/models/reading_progress.dart \
        app/lib/data/models/typography_settings.dart \
        app/lib/data/models/typography_profile.dart \
        app/lib/data/models/search_result.dart \
        app/test/data/models/reading_progress_test.dart \
        app/test/data/models/typography_settings_test.dart
git commit -m "feat(m1): ReadingProgress / TypographySettings / SearchResult / Profile

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase C：drift 数据库（M1.2）

### Task 11：drift 数据库连接与基础设置

**Files:**
- Create: `app/lib/data/local/connections/database_connection.dart`
- Create: `app/lib/data/local/database.dart`
- Create: `app/test/helpers/drift_test_helper.dart`
- Test: `app/test/data/local/database_test.dart`

- [ ] **Step 1：写失败测试（验证数据库可创建与连接）**

Create `app/test/helpers/drift_test_helper.dart`:
```dart
import 'package:zhiyue/data/local/database.dart';

/// 测试用：内存数据库 + 空表。
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting();
}
```

Create `app/test/data/local/database_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  test('database can be created and closed', () async {
    final db = createTestDatabase();
    expect(db, isNotNull);
    await db.close();
  });

  test('database version is 1', () {
    final db = createTestDatabase();
    expect(db.schemaVersion, 1);
    db.close();
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/local/database_test.dart
```

Expected: FAIL (AppDatabase / database_connection not found)。

- [ ] **Step 3：实现 `app/lib/data/local/connections/database_connection.dart`**

```dart
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// 生产环境数据库连接：写入应用文档目录下的 app.db。
LazyDatabase createDatabaseConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // 启用外键约束
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
```

- [ ] **Step 4：实现 `app/lib/data/local/database.dart`**

```dart
import 'package:drift/drift.dart';

import 'connections/database_connection.dart';

part 'database.g.dart';

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(createDatabaseConnection());

  /// 测试用：传入自定义 executor。
  @override
  int get schemaVersion => 1;
}

extension AppDatabaseTesting on AppDatabase {
  /// 测试工厂：内存数据库。
  factory AppDatabase.forTesting() = _AppDatabaseForTesting;
}

class _AppDatabaseForTesting extends AppDatabase {
  _AppDatabaseForTesting() : super(_testExecutor());

  static QueryExecutor _testExecutor() {
    return NativeDatabase.memory();
  }
}
```

> 注意：上面用 `factory` 关键字在 `extension` 里不行。改用命名构造函数。最终版见 Step 4b。

- [ ] **Step 4b：重写 `app/lib/data/local/database.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'connections/database_connection.dart';

part 'database.g.dart';

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(createDatabaseConnection());

  /// 测试用：内存数据库。
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
```

- [ ] **Step 5：生成 drift 代码**

Run:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

Expected: 生成 `database.g.dart`，无错误。

- [ ] **Step 6：运行测试验证通过**

Run:
```bash
flutter test test/data/local/database_test.dart
```

Expected: All passed.

- [ ] **Step 7：提交**

```bash
cd ..
git add app/lib/data/local/ app/test/helpers/ app/test/data/local/database_test.dart
git commit -m "feat(m1): drift 数据库连接与空 schema

- 生产环境 LazyDatabase 写入 app.db
- 测试用内存数据库
- 外键约束启用

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 12：所有 drift 表定义

**Files:**
- Create: `app/lib/data/local/tables/books.dart`
- Create: `app/lib/data/local/tables/book_notes.dart`
- Create: `app/lib/data/local/tables/annotations.dart`
- Create: `app/lib/data/local/tables/reading_progress.dart`
- Create: `app/lib/data/local/tables/typography_profiles.dart`
- Create: `app/lib/data/local/tables/book_typography_overrides.dart`
- Create: `app/lib/data/local/tables/settings.dart`
- Modify: `app/lib/data/local/database.dart`

- [ ] **Step 1：实现所有表定义**

Create `app/lib/data/local/tables/books.dart`:
```dart
import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text().clientDefault(_uuid)();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get format => text()(); // 'epub' | 'pdf'
  TextColumn get filePath => text()();
  TextColumn get fileHash => text()();
  IntColumn get fileSizeBytes => integer()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  String _uuid() => '';
}
```

> 注意：drift 的 `clientDefault` 不能这样写。表定义应当尽量简单。重写为：

Create `app/lib/data/local/tables/books.dart`（最终版）:
```dart
import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get format => text()(); // 'epub' | 'pdf'
  TextColumn get filePath => text()();
  TextColumn get fileHash => text()();
  IntColumn get fileSizeBytes => integer()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get addedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Create `app/lib/data/local/tables/book_notes.dart`:
```dart
import 'package:drift/drift.dart';

import 'books.dart';

class BookNotes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get title => text()();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get keyTakeaways =>
      text().withDefault(const Constant('[]'))(); // JSON 数组
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

Create `app/lib/data/local/tables/annotations.dart`:
```dart
import 'package:drift/drift.dart';

import 'book_notes.dart';

class Annotations extends Table {
  TextColumn get id => text()();
  TextColumn get bookNoteId => text().references(BookNotes, #id)();
  TextColumn get locator => text()(); // JSON
  TextColumn get quote => text()();
  TextColumn get note => text().nullable()();
  TextColumn get color => text()(); // 'yellow' | 'green' | 'blue' | 'red' | 'purple'
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON 数组
  TextColumn get source =>
      text().withDefault(const Constant('manual'))(); // 'manual' | 'aiAssisted'
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

Create `app/lib/data/local/tables/reading_progress.dart`:
```dart
import 'package:drift/drift.dart';

import 'books.dart';

class ReadingProgressTable extends Table {
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get locator => text()(); // JSON
  RealColumn get percent => real()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bookId};
}
```

Create `app/lib/data/local/tables/typography_profiles.dart`:
```dart
import 'package:drift/drift.dart';

class TypographyProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get settings => text()(); // JSON
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
```

Create `app/lib/data/local/tables/book_typography_overrides.dart`:
```dart
import 'package:drift/drift.dart';

import 'books.dart';
import 'typography_profiles.dart';

class BookTypographyOverrides extends Table {
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get profileId => text().nullable()();
  TextColumn get customSettings => text().nullable()(); // JSON

  @override
  Set<Column> get primaryKey => {bookId};
}
```

Create `app/lib/data/local/tables/settings.dart`:
```dart
import 'package:drift/drift.dart';

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON-encoded

  @override
  Set<Column> get primaryKey => {key};
}
```

- [ ] **Step 2：修改 `app/lib/data/local/database.dart` 注册所有表**

Replace 内容：
```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'connections/database_connection.dart';
import 'tables/annotations.dart';
import 'tables/book_notes.dart';
import 'tables/book_typography_overrides.dart';
import 'tables/books.dart';
import 'tables/reading_progress.dart';
import 'tables/settings.dart';
import 'tables/typography_profiles.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Books,
    BookNotes,
    Annotations,
    ReadingProgressTable,
    TypographyProfiles,
    BookTypographyOverrides,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(createDatabaseConnection());

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
```

- [ ] **Step 3：重新生成代码**

Run:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

Expected: 生成完整的 `database.g.dart`，无错误。

- [ ] **Step 4：验证 analyze**

Run:
```bash
flutter analyze
```

Expected: 无错误。

- [ ] **Step 5：提交**

```bash
cd ..
git add app/lib/data/local/tables/ app/lib/data/local/database.dart app/lib/data/local/database.g.dart
git commit -m "feat(m1): drift 表定义（7 张表）

books / book_notes / annotations / reading_progress / typography_profiles / book_typography_overrides / settings

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase D：DAOs（M1.3）

### Task 13：BooksDao

**Files:**
- Create: `app/lib/data/local/daos/books_dao.dart`
- Test: `app/test/data/local/daos/books_dao_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/local/daos/books_dao_test.dart`:
```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late BooksDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = BooksDao(db);
  });

  tearDown(() async => db.close());

  test('insert and getAll', () async {
    await dao.insertOne(
      id: 'b1',
      title: '与天为敌',
      author: '彼得·伯恩斯坦',
      format: 'epub',
      filePath: '/library/abc.epub',
      fileHash: 'abc',
      fileSizeBytes: 1024,
    );
    final all = await dao.getAll();
    expect(all, hasLength(1));
    expect(all.first.title, '与天为敌');
  });

  test('getById returns null when missing', () async {
    expect(await dao.getById('nonexistent'), isNull);
  });

  test('delete removes the book', () async {
    await dao.insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    await dao.delete('b1');
    expect(await dao.getAll(), isEmpty);
  });

  test('updateLastReadAt sets timestamp', () async {
    await dao.insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    final ts = DateTime(2026, 6, 24);
    await dao.updateLastReadAt('b1', ts);
    final book = await dao.getById('b1');
    expect(book?.lastReadAt, ts);
  });

  test('findByHash returns book for dedup', () async {
    await dao.insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'hash123',
      fileSizeBytes: 0,
    );
    final found = await dao.findByHash('hash123');
    expect(found?.id, 'b1');
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/local/daos/books_dao_test.dart
```

Expected: FAIL (BooksDao not found).

- [ ] **Step 3：实现 `app/lib/data/local/daos/books_dao.dart`**

```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/books.dart';

part 'books_dao.g.dart';

@DriftAccessor(tables: [Books])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  Future<List<Book>> getAll() => select(books).get();

  Future<Book?> getById(String id) =>
      (select(books)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Book?> findByHash(String hash) =>
      (select(books)..where((t) => t.fileHash.equals(hash)))
          .getSingleOrNull();

  Future<int> insertOne({
    required String id,
    required String title,
    String? author,
    required String format,
    required String filePath,
    required String fileHash,
    required int fileSizeBytes,
    String? coverPath,
  }) {
    return into(books).insert(
      BooksCompanion.insert(
        id: id,
        title: title,
        author: Value(author),
        format: format,
        filePath: filePath,
        fileHash: fileHash,
        fileSizeBytes: fileSizeBytes,
        coverPath: Value(coverPath),
      ),
    );
  }

  Future<int> updateLastReadAt(String id, DateTime ts) {
    return (update(books)..where((t) => t.id.equals(id)))
        .write(BooksCompanion(lastReadAt: Value(ts)));
  }

  Future<int> delete(String id) {
    return (delete(books)..where((t) => t.id.equals(id))).go();
  }
}
```

- [ ] **Step 4：把 DAO 注册到数据库并重新生成**

Modify `app/lib/data/local/database.dart` 添加 DAO 注册：
```dart
import 'daos/books_dao.dart';
// ... 其他 import 不变

@DriftDatabase(
  tables: [...],
  daos: [BooksDao],
)
class AppDatabase extends _$AppDatabase { ... }
```

Run:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/local/daos/books_dao_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/local/daos/books_dao.dart \
        app/lib/data/local/daos/books_dao.g.dart \
        app/lib/data/local/database.dart \
        app/lib/data/local/database.g.dart \
        app/test/data/local/daos/books_dao_test.dart
git commit -m "feat(m1): BooksDao

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 14：BookNotesDao

**Files:**
- Create: `app/lib/data/local/daos/book_notes_dao.dart`
- Test: `app/test/data/local/daos/book_notes_dao_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/local/daos/book_notes_dao_test.dart`:
```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/book_notes_dao.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late BookNotesDao dao;
  late BooksDao books;

  setUp(() async {
    db = createTestDatabase();
    dao = BookNotesDao(db);
    books = BooksDao(db);
    // 外键依赖，必须先插入 book
    await books.insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => db.close());

  test('insert and getByBookId', () async {
    await dao.insertOne(
      id: 'bn1',
      bookId: 'b1',
      title: '《t》读书笔记',
    );
    final note = await dao.getByBookId('b1');
    expect(note?.title, '《t》读书笔记');
  });

  test('update summary and keyTakeaways', () async {
    await dao.insertOne(id: 'bn1', bookId: 'b1', title: 't');
    await dao.updateContent(
      'bn1',
      summary: 's',
      keyTakeawaysJson: '["k1"]',
    );
    final note = await dao.getByBookId('b1');
    expect(note?.summary, 's');
    expect(note?.keyTakeaways, '["k1"]');
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/local/daos/book_notes_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/local/daos/book_notes_dao.dart`**

```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/book_notes.dart';

part 'book_notes_dao.g.dart';

@DriftAccessor(tables: [BookNotes])
class BookNotesDao extends DatabaseAccessor<AppDatabase>
    with _$BookNotesDaoMixin {
  BookNotesDao(super.db);

  Future<BookNote?> getByBookId(String bookId) {
    return (select(bookNotes)..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  Future<int> insertOne({
    required String id,
    required String bookId,
    required String title,
  }) {
    return into(bookNotes).insert(
      BookNotesCompanion.insert(
        id: id,
        bookId: bookId,
        title: title,
      ),
    );
  }

  Future<int> updateContent(
    String id, {
    String? summary,
    String? keyTakeawaysJson,
  }) {
    return (update(bookNotes)..where((t) => t.id.equals(id))).write(
      BookNotesCompanion(
        summary: summary == null ? const Value.absent() : Value(summary),
        keyTakeaways: keyTakeawaysJson == null
            ? const Value.absent()
            : Value(keyTakeawaysJson),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
```

- [ ] **Step 4：注册 DAO 并生成**

Modify `app/lib/data/local/database.dart` `daos: [BooksDao, BookNotesDao]`。

Run:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/local/daos/book_notes_dao_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/local/daos/book_notes_dao.dart \
        app/lib/data/local/daos/book_notes_dao.g.dart \
        app/lib/data/local/database.dart \
        app/lib/data/local/database.g.dart \
        app/test/data/local/daos/book_notes_dao_test.dart
git commit -m "feat(m1): BookNotesDao

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 15：AnnotationsDao（含 FTS5）

**Files:**
- Create: `app/lib/data/local/daos/annotations_dao.dart`
- Test: `app/test/data/local/daos/annotations_dao_test.dart`

> 注：FTS5 的完整集成涉及触发器，需要在数据库 `migration.onCreate` 里手工执行 SQL。本任务先做基础 DAO，FTS 全文搜索接口在 Task 22 的 NotesRepository 实现。

- [ ] **Step 1：写失败测试**

Create `app/test/data/local/daos/annotations_dao_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/annotations_dao.dart';
import 'package:zhiyue/data/local/daos/book_notes_dao.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late AnnotationsDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = AnnotationsDao(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    await BookNotesDao(db).insertOne(id: 'bn1', bookId: 'b1', title: 't');
  });

  tearDown(() async => db.close());

  test('insert and getByBookNoteId', () async {
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{"type":"epubCfi","cfi":"epubcfi(/6)","chapterIndex":0}',
      quote: '风险即未来',
      note: '笔记内容',
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
    );
    final all = await dao.getByBookNoteId('bn1');
    expect(all, hasLength(1));
    expect(all.first.quote, '风险即未来');
    expect(all.first.note, '笔记内容');
  });

  test('updateNote replaces note content', () async {
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{}',
      quote: '',
      note: null,
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
    );
    await dao.updateNote('a1', '新笔记');
    final all = await dao.getByBookNoteId('bn1');
    expect(all.first.note, '新笔记');
  });

  test('delete removes annotation', () async {
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{}',
      quote: '',
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
    );
    await dao.delete('a1');
    expect(await dao.getByBookNoteId('bn1'), isEmpty);
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/local/daos/annotations_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/local/daos/annotations_dao.dart`**

```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/annotations.dart';

part 'annotations_dao.g.dart';

@DriftAccessor(tables: [Annotations])
class AnnotationsDao extends DatabaseAccessor<AppDatabase>
    with _$AnnotationsDaoMixin {
  AnnotationsDao(super.db);

  Future<List<Annotation>> getByBookNoteId(String bookNoteId) {
    return (select(annotations)..where((t) => t.bookNoteId.equals(bookNoteId)))
        .get();
  }

  Future<int> insertOne({
    required String id,
    required String bookNoteId,
    required String locatorJson,
    required String quote,
    String? note,
    required String color,
    required String tagsJson,
    required String source,
  }) {
    return into(annotations).insert(
      AnnotationsCompanion.insert(
        id: id,
        bookNoteId: bookNoteId,
        locator: locatorJson,
        quote: quote,
        note: note == null ? const Value.absent() : Value(note),
        color: color,
        tags: Value(tagsJson),
        source: Value(source),
      ),
    );
  }

  Future<int> updateNote(String id, String? note) {
    return (update(annotations)..where((t) => t.id.equals(id))).write(
      AnnotationsCompanion(
        note: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> delete(String id) {
    return (delete(annotations)..where((t) => t.id.equals(id))).go();
  }
}
```

- [ ] **Step 4：注册 DAO 并生成**

Modify `app/lib/data/local/database.dart` `daos: [BooksDao, BookNotesDao, AnnotationsDao]`。

Run:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/local/daos/annotations_dao_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/local/daos/annotations_dao.* \
        app/lib/data/local/database.dart \
        app/lib/data/local/database.g.dart \
        app/test/data/local/daos/annotations_dao_test.dart
git commit -m "feat(m1): AnnotationsDao

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 16：ReadingProgressDao

**Files:**
- Create: `app/lib/data/local/daos/reading_progress_dao.dart`
- Test: `app/test/data/local/daos/reading_progress_dao_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/local/daos/reading_progress_dao_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/daos/reading_progress_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late ReadingProgressDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = ReadingProgressDao(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => db.close());

  test('upsert inserts then updates', () async {
    await dao.upsert(
      bookId: 'b1',
      locatorJson: '{"type":"epubCfi","cfi":"epubcfi(/1)","chapterIndex":0}',
      percent: 0.1,
    );
    var p = await dao.getByBookId('b1');
    expect(p?.percent, 0.1);

    await dao.upsert(
      bookId: 'b1',
      locatorJson: '{"type":"epubCfi","cfi":"epubcfi(/2)","chapterIndex":0}',
      percent: 0.5,
    );
    p = await dao.getByBookId('b1');
    expect(p?.percent, 0.5);
  });

  test('getByBookId returns null when missing', () async {
    expect(await dao.getByBookId('b1'), isNull);
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/local/daos/reading_progress_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/local/daos/reading_progress_dao.dart`**

```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/reading_progress.dart';

part 'reading_progress_dao.g.dart';

@DriftAccessor(tables: [ReadingProgressTable])
class ReadingProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingProgressDaoMixin {
  ReadingProgressDao(super.db);

  Future<ReadingProgressTableData?> getByBookId(String bookId) {
    return (select(readingProgressTable)
          ..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  /// Upsert：主键冲突时更新。
  Future<void> upsert({
    required String bookId,
    required String locatorJson,
    required double percent,
  }) async {
    await into(readingProgressTable).insertOnConflictUpdate(
      ReadingProgressTableCompanion.insert(
        bookId: bookId,
        locator: locatorJson,
        percent: percent,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
```

- [ ] **Step 4：注册 DAO 并生成**

Modify `database.dart` `daos: [..., ReadingProgressDao]`。

Run:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/local/daos/reading_progress_dao_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/local/daos/reading_progress_dao.* \
        app/lib/data/local/database.dart \
        app/lib/data/local/database.g.dart \
        app/test/data/local/daos/reading_progress_dao_test.dart
git commit -m "feat(m1): ReadingProgressDao (upsert)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 17：TypographyDao

**Files:**
- Create: `app/lib/data/local/daos/typography_dao.dart`
- Test: `app/test/data/local/daos/typography_dao_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/local/daos/typography_dao_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/typography_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late TypographyDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = TypographyDao(db);
  });

  tearDown(() async => db.close());

  test('insert profile and getAll', () async {
    await dao.insertProfile(
      id: 'p1',
      name: '默认',
      settingsJson: '{}',
      isDefault: true,
    );
    final all = await dao.getAllProfiles();
    expect(all, hasLength(1));
    expect(all.first.name, '默认');
  });

  test('getProfile returns null when missing', () async {
    expect(await dao.getProfile('nonexistent'), isNull);
  });

  test('override upsert', () async {
    await dao.upsertOverride(bookId: 'b1', customSettingsJson: '{"fontSize":18}');
    final override = await dao.getOverride('b1');
    expect(override?.customSettings, '{"fontSize":18}');
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/local/daos/typography_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/local/daos/typography_dao.dart`**

```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/book_typography_overrides.dart';
import '../tables/typography_profiles.dart';

part 'typography_dao.g.dart';

@DriftAccessor(tables: [TypographyProfiles, BookTypographyOverrides])
class TypographyDao extends DatabaseAccessor<AppDatabase>
    with _$TypographyDaoMixin {
  TypographyDao(super.db);

  Future<List<TypographyProfile>> getAllProfiles() => select(typographyProfiles).get();

  Future<TypographyProfile?> getProfile(String id) =>
      (select(typographyProfiles)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertProfile({
    required String id,
    required String name,
    required String settingsJson,
    required bool isDefault,
  }) {
    return into(typographyProfiles).insert(
      TypographyProfilesCompanion.insert(
        id: id,
        name: name,
        settings: settingsJson,
        isDefault: Value(isDefault),
      ),
    );
  }

  Future<BookTypographyOverride?> getOverride(String bookId) {
    return (select(bookTypographyOverrides)
          ..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  Future<void> upsertOverride({
    required String bookId,
    String? profileId,
    String? customSettingsJson,
  }) {
    return into(bookTypographyOverrides).insertOnConflictUpdate(
      BookTypographyOverridesCompanion.insert(
        bookId: bookId,
        profileId: profileId == null ? const Value.absent() : Value(profileId),
        customSettings: customSettingsJson == null
            ? const Value.absent()
            : Value(customSettingsJson),
      ),
    );
  }
}
```

- [ ] **Step 4：注册 DAO 并生成**

Modify `database.dart` `daos: [..., TypographyDao]`。

Run:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/local/daos/typography_dao_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/local/daos/typography_dao.* \
        app/lib/data/local/database.dart \
        app/lib/data/local/database.g.dart \
        app/test/data/local/daos/typography_dao_test.dart
git commit -m "feat(m1): TypographyDao (profiles + overrides)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 18：SettingsDao

**Files:**
- Create: `app/lib/data/local/daos/settings_dao.dart`
- Test: `app/test/data/local/daos/settings_dao_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/local/daos/settings_dao_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/settings_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late SettingsDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = SettingsDao(db);
  });

  tearDown(() async => db.close());

  test('get returns null for unknown key', () async {
    expect(await dao.get('missing'), isNull);
  });

  test('upsert then get', () async {
    await dao.upsert('theme', 'dark');
    expect(await dao.get('theme'), 'dark');

    await dao.upsert('theme', 'light');
    expect(await dao.get('theme'), 'light');
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/local/daos/settings_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/local/daos/settings_dao.dart`**

```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/settings.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> get(String key) {
    return (select(settings)..where((t) => t.key.equals(key)))
        .map((row) => row.value)
        .getSingleOrNull();
  }

  Future<void> upsert(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: key,
        value: value,
      ),
    );
  }
}
```

- [ ] **Step 4：注册 DAO 并生成**

Modify `database.dart` `daos: [..., SettingsDao]`。

Run:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/local/daos/settings_dao_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/local/daos/settings_dao.* \
        app/lib/data/local/database.dart \
        app/lib/data/local/database.g.dart \
        app/test/data/local/daos/settings_dao_test.dart
git commit -m "feat(m1): SettingsDao (KV store)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase E：Repositories（M1.4）

### Task 19：BookRepository 接口 + 本地实现

**Files:**
- Create: `app/lib/data/repositories/book_repository.dart`
- Create: `app/lib/data/repositories/local_book_repository.dart`
- Test: `app/test/data/repositories/book_repository_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/repositories/book_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late LocalBookRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = LocalBookRepository(db);
  });

  tearDown(() async => db.close());

  test('getAll returns empty initially', () async {
    expect(await repo.getAll(), isEmpty);
  });

  test('save and getById', () async {
    final book = Book(
      id: 'b1',
      title: '与天为敌',
      author: '伯恩斯坦',
      format: BookFormat.epub,
      filePath: '/lib/abc.epub',
      fileHash: 'abc',
      fileSizeBytes: 1024,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    final found = await repo.getById('b1');
    expect(found?.title, '与天为敌');
    expect(found?.format, BookFormat.epub);
  });

  test('findByHash returns book', () async {
    final book = Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.pdf,
      filePath: 'p',
      fileHash: 'h1',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    expect((await repo.findByHash('h1'))?.id, 'b1');
  });

  test('delete removes book', () async {
    final book = Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.epub,
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    await repo.delete('b1');
    expect(await repo.getAll(), isEmpty);
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/repositories/book_repository_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/repositories/book_repository.dart`（接口）**

```dart
import '../models/book.dart';

abstract class BookRepository {
  Future<List<Book>> getAll();
  Future<Book?> getById(String id);
  Future<Book?> findByHash(String hash);
  Future<void> save(Book book);
  Future<void> delete(String id);
}
```

- [ ] **Step 4：实现 `app/lib/data/repositories/local_book_repository.dart`**

```dart
import 'package:drift/drift.dart' show Value;

import '../local/database.dart';
import '../local/daos/books_dao.dart';
import '../models/book.dart';
import 'book_repository.dart';

class LocalBookRepository implements BookRepository {
  final BooksDao _dao;

  LocalBookRepository(AppDatabase db) : _dao = BooksDao(db);

  @override
  Future<List<Book>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_toModel).toList();
  }

  @override
  Future<Book?> getById(String id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<Book?> findByHash(String hash) async {
    final row = await _dao.findByHash(hash);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> save(Book book) async {
    final existing = await _dao.getById(book.id);
    if (existing == null) {
      await _dao.insertOne(
        id: book.id,
        title: book.title,
        author: book.author,
        format: book.format == BookFormat.epub ? 'epub' : 'pdf',
        filePath: book.filePath,
        fileHash: book.fileHash,
        fileSizeBytes: book.fileSizeBytes,
        coverPath: book.coverPath,
      );
    } else {
      // 已存在：保留原 addedAt，更新其他字段
      // M1 阶段书籍元数据不变更，此处实际不做更新（避免覆盖导入时的字段）
    }
  }

  @override
  Future<void> delete(String id) => _dao.delete(id);

  Book _toModel(BookRow row) {
    return Book(
      id: row.id,
      title: row.title,
      author: row.author,
      format: row.format == 'epub' ? BookFormat.epub : BookFormat.pdf,
      filePath: row.filePath,
      fileHash: row.fileHash,
      fileSizeBytes: row.fileSizeBytes,
      coverPath: row.coverPath,
      addedAt: row.addedAt,
      lastReadAt: row.lastReadAt,
    );
  }
}
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/repositories/book_repository_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/repositories/book_repository.dart \
        app/lib/data/repositories/local_book_repository.dart \
        app/test/data/repositories/book_repository_test.dart
git commit -m "feat(m1): BookRepository + 本地实现

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 20：ReadingProgressRepository + 本地实现

**Files:**
- Create: `app/lib/data/repositories/reading_progress_repository.dart`
- Create: `app/lib/data/repositories/local_reading_progress_repository.dart`
- Test: `app/test/data/repositories/reading_progress_repository_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/repositories/reading_progress_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/local_reading_progress_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late LocalReadingProgressRepository repo;

  setUp(() async {
    db = createTestDatabase();
    repo = LocalReadingProgressRepository(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => db.close());

  test('save and get', () async {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 0.3,
      updatedAt: DateTime(2026, 6, 24),
    );
    await repo.save(p);
    final found = await repo.get('b1');
    expect(found?.percent, 0.3);
    expect(found?.locator, isA<EpubCfiLocator>());
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/repositories/reading_progress_repository_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/repositories/reading_progress_repository.dart`**

```dart
import '../models/reading_progress.dart';

abstract class ReadingProgressRepository {
  Future<ReadingProgress?> get(String bookId);
  Future<void> save(ReadingProgress progress);
}
```

- [ ] **Step 4：实现 `app/lib/data/repositories/local_reading_progress_repository.dart`**

```dart
import '../../core/locator.dart';
import '../local/database.dart';
import '../local/daos/reading_progress_dao.dart';
import '../models/reading_progress.dart';
import 'reading_progress_repository.dart';

class LocalReadingProgressRepository
    implements ReadingProgressRepository {
  final ReadingProgressDao _dao;

  LocalReadingProgressRepository(AppDatabase db)
      : _dao = ReadingProgressDao(db);

  @override
  Future<ReadingProgress?> get(String bookId) async {
    final row = await _dao.getByBookId(bookId);
    if (row == null) return null;
    return ReadingProgress(
      bookId: row.bookId,
      locator: Locator.fromJson(
        _decodeJson(row.locator),
      ),
      percent: row.percent,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> save(ReadingProgress progress) {
    return _dao.upsert(
      bookId: progress.bookId,
      locatorJson: _encodeJson(progress.locator.toJson()),
      percent: progress.percent,
    );
  }

  Map<String, dynamic> _decodeJson(String s) =>
      _jsonDecoder.convert(s) as Map<String, dynamic>;
  String _encodeJson(Map<String, dynamic> m) => _jsonEncoder.convert(m);

  static final _jsonDecoder = const JsonDecoder();
  static final _jsonEncoder = const JsonEncoder();
}

// 顶层常量（避免 import 冲突，dart:convert 直接用）
const JsonDecoder = _JsonDecoderStub();
const JsonEncoder = _JsonEncoderStub();

class _JsonDecoderStub {
  const _JsonDecoderStub();
  dynamic convert(String s) {
    // ignore: avoid_dynamic_calls
    return _import.jsonDecode(s);
  }
}

class _JsonEncoderStub {
  const _JsonEncoderStub();
  String convert(Object? o) => _import.jsonEncode(o);
}

// ignore: avoid_relative_lib_imports
import 'dart:convert' as _import;
```

> 注意：上面的代码不合法（import 必须在文件顶部，不能有 alias 重复）。重写最终版见 Step 4b。

- [ ] **Step 4b：重写 `app/lib/data/repositories/local_reading_progress_repository.dart`**

```dart
import 'dart:convert';

import '../../core/locator.dart';
import '../local/database.dart';
import '../local/daos/reading_progress_dao.dart';
import '../models/reading_progress.dart';
import 'reading_progress_repository.dart';

class LocalReadingProgressRepository
    implements ReadingProgressRepository {
  final ReadingProgressDao _dao;

  LocalReadingProgressRepository(AppDatabase db)
      : _dao = ReadingProgressDao(db);

  @override
  Future<ReadingProgress?> get(String bookId) async {
    final row = await _dao.getByBookId(bookId);
    if (row == null) return null;
    return ReadingProgress(
      bookId: row.bookId,
      locator: Locator.fromJson(
        jsonDecode(row.locator) as Map<String, dynamic>,
      ),
      percent: row.percent,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> save(ReadingProgress progress) {
    return _dao.upsert(
      bookId: progress.bookId,
      locatorJson: jsonEncode(progress.locator.toJson()),
      percent: progress.percent,
    );
  }
}
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/repositories/reading_progress_repository_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/repositories/reading_progress_repository.dart \
        app/lib/data/repositories/local_reading_progress_repository.dart \
        app/test/data/repositories/reading_progress_repository_test.dart
git commit -m "feat(m1): ReadingProgressRepository + 本地实现

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 21：NotesRepository + 本地实现

**Files:**
- Create: `app/lib/data/repositories/notes_repository.dart`
- Create: `app/lib/data/repositories/local_notes_repository.dart`
- Test: `app/test/data/repositories/notes_repository_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/repositories/notes_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/local_notes_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late LocalNotesRepository repo;

  setUp(() async {
    db = createTestDatabase();
    repo = LocalNotesRepository(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => db.close());

  test('createEmptyNote then getNoteByBook returns it', () async {
    final note = await repo.createEmptyNote(
      id: 'bn1',
      bookId: 'b1',
      bookTitle: 't',
    );
    expect(note.title, '《t》读书笔记');

    final found = await repo.getNoteByBook('b1');
    expect(found?.id, 'bn1');
  });

  test('addAnnotation then listAnnotations', () async {
    await repo.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    final a = Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      quote: '风险',
      note: '思考',
      color: HighlightColor.yellow,
      tags: const ['风险'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 6, 24),
      updatedAt: DateTime(2026, 6, 24),
    );
    await repo.addAnnotation(a);
    final list = await repo.listAnnotations('bn1');
    expect(list, hasLength(1));
    expect(list.first.quote, '风险');
    expect(list.first.color, HighlightColor.yellow);
  });

  test('updateAnnotation changes note', () async {
    await repo.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    final a = Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      quote: '',
      note: '旧',
      color: HighlightColor.yellow,
      tags: const [],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 6, 24),
      updatedAt: DateTime(2026, 6, 24),
    );
    await repo.addAnnotation(a);
    await repo.updateAnnotation(a.copyWith(note: '新'));
    final list = await repo.listAnnotations('bn1');
    expect(list.first.note, '新');
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/repositories/notes_repository_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/repositories/notes_repository.dart`**

```dart
import '../models/annotation.dart';
import '../models/book_note.dart';

abstract class NotesRepository {
  Future<BookNote?> getNoteByBook(String bookId);
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  });
  Future<void> updateNote(BookNote note);
  Future<List<Annotation>> listAnnotations(String noteId);
  Future<void> addAnnotation(Annotation annotation);
  Future<void> updateAnnotation(Annotation annotation);
  Future<void> deleteAnnotation(String id);
  Future<List<Annotation>> searchAnnotations(
    String query, {
    List<String>? tags,
  });
}
```

- [ ] **Step 4：实现 `app/lib/data/repositories/local_notes_repository.dart`**

```dart
import 'dart:convert';

import '../../core/locator.dart';
import '../local/database.dart';
import '../local/daos/annotations_dao.dart';
import '../local/daos/book_notes_dao.dart';
import '../models/annotation.dart';
import '../models/book_note.dart';
import 'notes_repository.dart';

class LocalNotesRepository implements NotesRepository {
  final BookNotesDao _notesDao;
  final AnnotationsDao _annotationsDao;

  LocalNotesRepository(AppDatabase db)
      : _notesDao = BookNotesDao(db),
        _annotationsDao = AnnotationsDao(db);

  @override
  Future<BookNote?> getNoteByBook(String bookId) async {
    final row = await _notesDao.getByBookId(bookId);
    if (row == null) return null;
    final annotations = await listAnnotations(row.id);
    return BookNote(
      id: row.id,
      bookId: row.bookId,
      title: row.title,
      summary: row.summary,
      keyTakeaways: _decodeStringList(row.keyTakeaways),
      annotations: annotations,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  }) async {
    final note = BookNote.empty(id: id, bookId: bookId, bookTitle: bookTitle);
    await _notesDao.insertOne(id: id, bookId: bookId, title: note.title);
    return note;
  }

  @override
  Future<void> updateNote(BookNote note) {
    return _notesDao.updateContent(
      note.id,
      summary: note.summary,
      keyTakeawaysJson: jsonEncode(note.keyTakeaways.toList()),
    );
  }

  @override
  Future<List<Annotation>> listAnnotations(String noteId) async {
    final rows = await _annotationsDao.getByBookNoteId(noteId);
    return rows.map(_toAnnotationModel).toList();
  }

  @override
  Future<void> addAnnotation(Annotation a) {
    return _annotationsDao.insertOne(
      id: a.id,
      bookNoteId: a.bookNoteId,
      locatorJson: jsonEncode(a.locator.toJson()),
      quote: a.quote,
      note: a.note,
      color: _colorToString(a.color),
      tagsJson: jsonEncode(a.tags.toList()),
      source: a.source == AnnotationSource.manual ? 'manual' : 'aiAssisted',
    );
  }

  @override
  Future<void> updateAnnotation(Annotation a) async {
    // 简单实现：delete + insert。生产可改为 update。
    await _annotationsDao.delete(a.id);
    await addAnnotation(a);
  }

  @override
  Future<void> deleteAnnotation(String id) => _annotationsDao.delete(id);

  @override
  Future<List<Annotation>> searchAnnotations(
    String query, {
    List<String>? tags,
  }) async {
    // M1 简单实现：拉所有 annotation 后内存过滤。
    // 真正的 FTS5 全文搜索在 M6（笔记库 UI 阶段）实现。
    final results = <Annotation>[];
    // 注：搜索实现需要遍历所有 note。M1 阶段先返回空。
    return results;
  }

  // ====== 私有 helpers ======

  Annotation _toAnnotationModel(AnnotationRow row) {
    return Annotation(
      id: row.id,
      bookNoteId: row.bookNoteId,
      locator: Locator.fromJson(
        jsonDecode(row.locator) as Map<String, dynamic>,
      ),
      quote: row.quote,
      note: row.note,
      color: _colorFromString(row.color),
      tags: _decodeStringList(row.tags),
      source: row.source == 'aiAssisted'
          ? AnnotationSource.aiAssisted
          : AnnotationSource.manual,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String _colorToString(HighlightColor c) {
    switch (c) {
      case HighlightColor.yellow:
        return 'yellow';
      case HighlightColor.green:
        return 'green';
      case HighlightColor.blue:
        return 'blue';
      case HighlightColor.red:
        return 'red';
      case HighlightColor.purple:
        return 'purple';
    }
  }

  HighlightColor _colorFromString(String s) {
    return HighlightColor.values.firstWhere(
      (c) => _colorToString(c) == s,
      orElse: () => HighlightColor.yellow,
    );
  }

  List<String> _decodeStringList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.cast<String>();
  }
}
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/repositories/notes_repository_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/repositories/notes_repository.dart \
        app/lib/data/repositories/local_notes_repository.dart \
        app/test/data/repositories/notes_repository_test.dart
git commit -m "feat(m1): NotesRepository + 本地实现

BookNote CRUD + Annotation CRUD + 颜色/标签/JSON 序列化

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 22：SettingsRepository + 本地实现

**Files:**
- Create: `app/lib/data/repositories/settings_repository.dart`
- Create: `app/lib/data/repositories/local_settings_repository.dart`
- Test: `app/test/data/repositories/settings_repository_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/repositories/settings_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/local_settings_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late LocalSettingsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = LocalSettingsRepository(db);
  });

  tearDown(() async => db.close());

  test('get returns default for missing key', () async {
    expect(await repo.get<String>('missing', 'fallback'), 'fallback');
  });

  test('set then get', () async {
    await repo.set<int>('fontSize', 18);
    expect(await repo.get<int>('fontSize', 0), 18);
  });

  test('set then get bool', () async {
    await repo.set<bool>('isDark', true);
    expect(await repo.get<bool>('isDark', false), isTrue);
  });

  test('set then get double', () async {
    await repo.set<double>('lineHeight', 1.6);
    expect(await repo.get<double>('lineHeight', 1.5), 1.6);
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/repositories/settings_repository_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/repositories/settings_repository.dart`**

```dart
abstract class SettingsRepository {
  Future<T> get<T>(String key, T defaultValue);
  Future<void> set<T>(String key, T value);
}
```

- [ ] **Step 4：实现 `app/lib/data/repositories/local_settings_repository.dart`**

```dart
import 'dart:convert';

import '../local/database.dart';
import '../local/daos/settings_dao.dart';
import 'settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  final SettingsDao _dao;

  LocalSettingsRepository(AppDatabase db) : _dao = SettingsDao(db);

  @override
  Future<T> get<T>(String key, T defaultValue) async {
    final raw = await _dao.get(key);
    if (raw == null) return defaultValue;
    return _decode<T>(raw);
  }

  @override
  Future<void> set<T>(String key, T value) {
    return _dao.upsert(key, jsonEncode(value));
  }

  T _decode<T>(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is T) return decoded;
    // 处理 int 与 double 互换等边界情况
    if (T == double && decoded is int) return decoded.toDouble() as T;
    if (T == int && decoded is double) return decoded.toInt() as T;
    throw StateError('Cannot decode $raw as $T');
  }
}
```

- [ ] **Step 5：运行测试验证通过**

Run:
```bash
flutter test test/data/repositories/settings_repository_test.dart
```

Expected: All passed.

- [ ] **Step 6：提交**

```bash
cd ..
git add app/lib/data/repositories/settings_repository.dart \
        app/lib/data/repositories/local_settings_repository.dart \
        app/test/data/repositories/settings_repository_test.dart
git commit -m "feat(m1): SettingsRepository + 本地实现

JSON 编码的 KV 存储，支持 int/double/bool/String

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase F：文件存储与导入（M1.5）

### Task 23：FileStorage 抽象

**Files:**
- Create: `app/lib/data/local/file_storage.dart`
- Test: `app/test/data/local/file_storage_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/local/file_storage_test.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/local/file_storage.dart';

void main() {
  late FileStorage storage;
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('zhiyue_storage_test_');
    storage = FileStorage(rootDir: tempRoot);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('library file is stored by hash and extension', () async {
    final source = File(p.join(tempRoot.path, 'source.epub'))
      ..writeAsBytesSync([1, 2, 3]);
    final stored = await storage.storeLibraryFile(
      source: source,
      fileHash: 'abc',
      extension: 'epub',
    );
    expect(p.basename(stored.path), 'abc.epub');
    expect(stored.existsSync(), isTrue);
  });

  test('cover file is stored by bookId', () async {
    final source = File(p.join(tempRoot.path, 'cover.png'))
      ..writeAsBytesSync([4, 5, 6]);
    final stored = await storage.storeCover(
      source: source,
      bookId: 'b1',
      extension: 'png',
    );
    expect(p.basename(stored.path), 'b1.png');
    expect(stored.existsSync(), isTrue);
  });

  test('deleteLibraryFile removes by hash', () async {
    final source = File(p.join(tempRoot.path, 's.epub'))
      ..writeAsBytesSync([1]);
    final stored = await storage.storeLibraryFile(
      source: source,
      fileHash: 'abc',
      extension: 'epub',
    );
    await storage.deleteLibraryFile(hash: 'abc', extension: 'epub');
    expect(stored.existsSync(), isFalse);
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/local/file_storage_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/data/local/file_storage.dart`**

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 文件系统抽象层。
///
/// 三类文件目录：
/// - `library/`：原始书籍文件，按 {fileHash}.{ext} 去重存储
/// - `covers/`：封面缓存，按 {bookId}.{ext} 存储
/// - `cache/`：渲染缓存，可清除
class FileStorage {
  final Directory rootDir;

  FileStorage({Directory? rootDir})
      : rootDir = rootDir ?? _defaultRootSync();

  /// 测试用：传入自定义根目录。
  const FileStorage.forTesting({required this.rootDir});

  static Directory _defaultRootSync() {
    // 仅测试时使用，生产代码请用异步工厂 [create].
    throw UnimplementedError('Use FileStorage.create() for production');
  }

  /// 生产工厂：从 path_provider 获取应用文档目录。
  static Future<FileStorage> create() async {
    final dir = await getApplicationDocumentsDirectory();
    return FileStorage(rootDir: dir);
  }

  Directory get libraryDir =>
      Directory(p.join(rootDir.path, 'library'))..createSync(recursive: true);
  Directory get coversDir =>
      Directory(p.join(rootDir.path, 'covers'))..createSync(recursive: true);
  Directory get cacheDir =>
      Directory(p.join(rootDir.path, 'cache'))..createSync(recursive: true);

  Future<File> storeLibraryFile({
    required File source,
    required String fileHash,
    required String extension,
  }) async {
    final dest = File(p.join(libraryDir.path, '$fileHash.$extension'));
    await source.copy(dest.path);
    return dest;
  }

  Future<File> storeCover({
    required File source,
    required String bookId,
    required String extension,
  }) async {
    final dest = File(p.join(coversDir.path, '$bookId.$extension'));
    await source.copy(dest.path);
    return dest;
  }

  Future<void> deleteLibraryFile({
    required String hash,
    required String extension,
  }) async {
    final file = File(p.join(libraryDir.path, '$hash.$extension'));
    if (await file.exists()) await file.delete();
  }

  Future<void> clearCache() async {
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create(recursive: true);
    }
  }
}
```

> 注意：测试用 `FileStorage(rootDir: tempRoot)`，但生产构造函数 `FileStorage(rootDir: dir)` 是合法的（命名参数），与 `_defaultRootSync()` 抛异常没有冲突。生产代码请用 `FileStorage.create()` 异步工厂。

- [ ] **Step 4：运行测试验证通过**

Run:
```bash
flutter test test/data/local/file_storage_test.dart
```

Expected: All passed.

- [ ] **Step 5：提交**

```bash
cd ..
git add app/lib/data/local/file_storage.dart \
        app/test/data/local/file_storage_test.dart
git commit -m "feat(m1): FileStorage 文件系统抽象

library/{hash}.{ext} 去重存储 + covers/{bookId}.{ext} + cache/

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

### Task 24：BookImportService（hash + dedup + 入库）

**Files:**
- Create: `app/lib/services/book_import_service.dart`
- Test: `app/test/data/services/book_import_service_test.dart`

- [ ] **Step 1：写失败测试**

Create `app/test/data/services/book_import_service_test.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/file_storage.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';
import 'package:zhiyue/services/book_import_service.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late Directory tempRoot;
  late FileStorage storage;
  late LocalBookRepository bookRepo;
  late BookImportService service;

  setUp(() async {
    db = createTestDatabase();
    bookRepo = LocalBookRepository(db);
    tempRoot = await Directory.systemTemp.createTemp('zhiyue_import_test_');
    storage = FileStorage(rootDir: tempRoot);
    service = BookImportService(
      bookRepository: bookRepo,
      fileStorage: storage,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('importFile stores file by hash and creates Book record', () async {
    final source = File(p.join(tempRoot.path, 'book.epub'))
      ..writeAsBytesSync([1, 2, 3, 4, 5]);

    final result = await service.importFile(source, format: BookFormat.epub);

    expect(result.isNew, isTrue);
    expect(result.book.title, 'book.epub'); // 无元数据时用文件名
    expect(result.book.format, BookFormat.epub);

    final stored = File(p.join(
      storage.libraryDir.path,
      '${result.book.fileHash}.epub',
    ));
    expect(stored.existsSync(), isTrue);
  });

  test('importFile dedups by hash', () async {
    final source1 = File(p.join(tempRoot.path, 'book1.epub'))
      ..writeAsBytesSync([1, 2, 3]);
    final source2 = File(p.join(tempRoot.path, 'book2.epub'))
      ..writeAsBytesSync([1, 2, 3]); // 同内容 → 同 hash

    final r1 = await service.importFile(source1, format: BookFormat.epub);
    final r2 = await service.importFile(source2, format: BookFormat.epub);

    expect(r1.isNew, isTrue);
    expect(r2.isNew, isFalse); // dedup
    expect(r2.book.id, r1.book.id);
  });
}
```

- [ ] **Step 2：运行测试验证失败**

Run:
```bash
cd app
flutter test test/data/services/book_import_service_test.dart
```

Expected: FAIL.

- [ ] **Step 3：实现 `app/lib/services/book_import_service.dart`**

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/local/file_storage.dart';
import '../data/models/book.dart';
import '../data/repositories/book_repository.dart';

class ImportResult {
  final Book book;
  final bool isNew;

  const ImportResult({required this.book, required this.isNew});
}

class BookImportService {
  final BookRepository _bookRepository;
  final FileStorage _fileStorage;
  final Uuid _uuid;

  BookImportService({
    required BookRepository bookRepository,
    required FileStorage fileStorage,
    Uuid? uuid,
  })  : _bookRepository = bookRepository,
        _fileStorage = fileStorage,
        _uuid = uuid ?? const Uuid();

  Future<ImportResult> importFile(
    File source, {
    required BookFormat format,
  }) async {
    final bytes = await source.readAsBytes();
    final hash = sha1.convert(bytes).toString();
    final extension = format == BookFormat.epub ? 'epub' : 'pdf';

    // Dedup by hash
    final existing = await _bookRepository.findByHash(hash);
    if (existing != null) {
      return ImportResult(book: existing, isNew: false);
    }

    // Store file
    final stored = await _fileStorage.storeLibraryFile(
      source: source,
      fileHash: hash,
      extension: extension,
    );

    // Create book record
    final fileName = p.basenameWithoutExtension(source.path);
    final book = Book(
      id: _uuid.v4(),
      title: fileName,
      author: null,
      format: format,
      filePath: stored.path,
      fileHash: hash,
      fileSizeBytes: bytes.length,
      coverPath: null,
      addedAt: DateTime.now(),
      lastReadAt: null,
    );
    await _bookRepository.save(book);

    return ImportResult(book: book, isNew: true);
  }
}
```

- [ ] **Step 4：运行测试验证通过**

Run:
```bash
flutter test test/data/services/book_import_service_test.dart
```

Expected: All passed.

- [ ] **Step 5：提交**

```bash
cd ..
git add app/lib/services/book_import_service.dart \
        app/test/data/services/book_import_service_test.dart
git commit -m "feat(m1): BookImportService

SHA-1 hash 去重 + 文件存储 + 元数据入 Books 表

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase G：M0+M1 整合（M1.6）

### Task 25：Riverpod Provider 注册 + 集成冒烟测试 + 数据层完成提交

**Files:**
- Modify: `app/lib/core/app_providers.dart`
- Create: `app/lib/core/providers.dart`
- Create: `app/integration_test/app_smoke_test.dart`

- [ ] **Step 1：实现 `app/lib/core/providers.dart`（Riverpod providers）**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../data/local/file_storage.dart';
import '../data/repositories/local_book_repository.dart';
import '../data/repositories/local_notes_repository.dart';
import '../data/repositories/local_reading_progress_repository.dart';
import '../data/repositories/local_settings_repository.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/reading_progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/book_import_service.dart';

/// 全局单例 AppDatabase。M1 阶段无同步包装。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final fileStorageProvider = FutureProvider<FileStorage>((ref) async {
  return FileStorage.create();
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return LocalBookRepository(ref.watch(appDatabaseProvider));
});

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  return LocalReadingProgressRepository(ref.watch(appDatabaseProvider));
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return LocalNotesRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return LocalSettingsRepository(ref.watch(appDatabaseProvider));
});

final bookImportServiceProvider = FutureProvider<BookImportService>((ref) async {
  final storage = await ref.watch(fileStorageProvider.future);
  return BookImportService(
    bookRepository: ref.watch(bookRepositoryProvider),
    fileStorage: storage,
  );
});
```

- [ ] **Step 2：更新 `app/lib/core/app_providers.dart`**

Replace 内容：
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 兼容入口：M0 占位文件，实际 providers 在 providers.dart。
final providers = <Override>[];
```

- [ ] **Step 3：写集成冒烟测试**

Create `app/integration_test/app_smoke_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiyue/core/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots end-to-end', (tester) async {
    await tester.pumpWidget(const ZhiYueApp());
    await tester.pumpAndSettle();
    expect(find.text('智阅'), findsOneWidget);
  });
}
```

- [ ] **Step 4：运行所有测试**

Run:
```bash
cd app
flutter test
```

Expected: All tests passed (models + DAOs + repositories + services + widget).

- [ ] **Step 5：运行 analyze + format**

Run:
```bash
dart format lib/ test/ integration_test/
flutter analyze
```

Expected: format 无 diff，analyze 无错误。

- [ ] **Step 6：提交（M0+M1 完成）**

```bash
cd ..
git add app/lib/core/providers.dart app/lib/core/app_providers.dart \
        app/integration_test/app_smoke_test.dart
git commit -m "feat(m1): Riverpod providers 注册 + 集成冒烟测试

M0 + M1 完成：
- Flutter 项目脚手架（Riverpod / drift / go_router）
- 7 张 drift 表 + 6 个 DAO + 4 个 Repository
- 领域模型：Book / BookNote / Annotation / ReadingProgress / Typography / SearchResult
- FileStorage + BookImportService（SHA-1 hash 去重）
- 完整测试覆盖（模型层 / DAO 层 / Repository 层 / 服务层）

下一步：M2 - EPUB 阅读器（解析/渲染/翻页/目录/进度）

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

- [ ] **Step 7：标记 M0+M1 完成（更新 README）**

Modify `README.md` 的"项目状态"段：
```markdown
## 项目状态

✅ **MVP 1.0 - M0 + M1 完成**：项目脚手架 + 数据层基础（drift SQLite + Repository + 文件存储）

🚧 下一步：**M2 - EPUB 阅读器**
```

- [ ] **Step 8：提交 README 更新**

```bash
git add README.md
git commit -m "docs: M0+M1 完成，更新项目状态

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## M0 + M1 完成验收清单

执行完所有 25 个任务后，应满足：

- [ ] Flutter 项目在 `app/` 子目录可独立运行（`flutter run -d windows` / `flutter run -d android`）
- [ ] `flutter analyze` 无错误
- [ ] `flutter test` 全部通过（约 40+ 测试用例）
- [ ] `flutter test integration_test/` 冒烟测试通过
- [ ] drift schema v1 包含 7 张表
- [ ] 所有 Repository 接口都有本地实现 + 单元测试
- [ ] FileStorage 在测试中可正确存储/读取/删除
- [ ] BookImportService 可对同一文件去重
- [ ] Gitee 远程仓库已收到所有 commit
- [ ] README 已更新状态

## 下一步

M0+M1 完成后，进入 **M2 - EPUB 阅读器**（4 周工期）。届时会创建新计划文档 `2026-XX-XX-m2-epub-reader.md`。

M2 是项目的关键 go/no-go 决策点（早期评估 `epub_view` / `vepub`，不满足则 fork 或自研）。建议在开始 M2 之前，专门花 1-2 天做技术调研 spike。
