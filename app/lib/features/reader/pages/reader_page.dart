// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/loading_view.dart';
import '../controllers/bookmark_controller.dart';
import '../providers/notes_controller.dart';
import '../providers/reader_engine_provider.dart';
import '../services/progress_persister.dart';
import '../widgets/reader_error_view.dart';
import 'reader_body.dart';

// Re-export public helpers used by tests + body internals, so existing
// `import .../reader_page.dart;` keeps working after T8 split (2026-06-30).
export 'reader_body.dart' show resolveSelectionLocator;
export 'reader_progress_bar.dart' show chapterOrPageLabel, estimateProgressPercent;

/// 阅读器主页面。
///
/// 装配链：[ReaderEngineProvider] → [ReaderPage] → [ReaderBody] →
/// [ReaderScaffold] → HtmlWidget。
///
/// 路由：`/book/:id`，由 `core/app.dart` 的 `onGenerateRoute` 派发。
///
/// T8 (2026-06-30) 拆分后本文件只保留 page-level wrapper（state + lifecycle）；
/// body composition 移到 [ReaderBody]，进度条移到 `reader_progress_bar.dart`，
/// typography 触发器移到 `reader_typography_panel_trigger.dart`。
class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;
  final Locator? initialLocator;

  const ReaderPage({super.key, required this.bookId, this.initialLocator});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  ProgressPersister? _persister;

  @override
  void dispose() {
    _persister?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engineAsync = ref.watch(readerEngineForBookProvider(widget.bookId));

    return Scaffold(
      body: engineAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ReaderErrorView(
          message: '无法打开书籍: $e',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        data: (engine) {
          _ensureProgressPersister(engine);
          // 用本地 ProviderScope 覆盖 currentBookIdProvider，让 NotesController
          // 拿到当前 bookId（仅作用于本书的子树）。
          // notesControllerProvider / bookmarkControllerProvider 都是 autoDispose
          // 且 ref.watch(currentBookIdProvider) — 同作用域覆盖依赖时必须同步
          // 覆盖所有消费方 provider，否则 riverpod 抛 "dependency overridden
          // but the provider is not" 断言（M2.10/Bug C2：漏了
          // bookmarkControllerProvider → 书签 tab 红屏黄字）。
          return ProviderScope(
            overrides: [
              currentBookIdProvider.overrideWith((_) => widget.bookId),
              notesControllerProvider.overrideWith(
                (ref) => NotesController(
                  bookId: widget.bookId,
                  repository: ref.watch(notesRepositoryProvider),
                ),
              ),
              // M2.10/Bug C2: bookmarkControllerProvider 同样依赖
              // currentBookIdProvider，必须一起 override，否则 reader 子树内
              // ReaderBookmarkList 读它时触发 Riverpod 断言红屏。
              bookmarkControllerProvider.overrideWith(
                (ref) => BookmarkController(
                  bookId: widget.bookId,
                  repository: ref.watch(bookmarkRepositoryProvider),
                ),
              ),
            ],
            child: ReaderBody(
              engine: engine,
              bookId: widget.bookId,
              initialLocator: widget.initialLocator,
            ),
          );
        },
      ),
    );
  }

  void _ensureProgressPersister(ReaderEngine engine) {
    if (_persister != null) return;
    _persister = ProgressPersister(
      bookId: widget.bookId,
      repository: ref.read(readingProgressRepositoryProvider),
      source: engine.currentLocation$,
    )..start();
  }
}
