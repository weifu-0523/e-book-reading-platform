import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/engine/reader_engine.dart';

import '../../../core/providers.dart';
import '../providers/reader_engine_provider.dart';
import '../services/progress_persister.dart';
import '../widgets/reader_error_view.dart';
import '../widgets/reader_scaffold.dart';

/// 阅读器主页面。
///
/// 装配链：[ReaderEngineProvider] → [ReaderPage] → [ReaderScaffold] → HtmlWidget。
///
/// 路由：`/book/:id`，由 `core/app.dart` 的 `onGenerateRoute` 派发。
class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderPage({super.key, required this.bookId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  ProgressPersister? _persister;
  ReaderEngine? _engine;

  @override
  void dispose() {
    _persister?.dispose();
    _engine?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engineAsync = ref.watch(readerEngineForBookProvider(widget.bookId));

    return Scaffold(
      body: engineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ReaderErrorView(
          message: '无法打开书籍: $e',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        data: (engine) {
          _ensureProgressPersister(engine);
          return _ReaderBody(engine: engine);
        },
      ),
    );
  }

  void _ensureProgressPersister(ReaderEngine engine) {
    if (_persister != null) return;
    _engine = engine;
    _persister = ProgressPersister(
      bookId: widget.bookId,
      repository: ref.read(readingProgressRepositoryProvider),
      source: engine.currentLocation$,
    )..start();
  }
}

class _ReaderBody extends StatelessWidget {
  final ReaderEngine engine;

  const _ReaderBody({required this.engine});

  @override
  Widget build(BuildContext context) {
    return ReaderScaffold(
      content: engine.build(context),
      onTapPrev: () => engine.previousSpine(),
      onTapNext: () => engine.nextSpine(),
    );
  }
}
