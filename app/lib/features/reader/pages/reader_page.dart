import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';

import '../../../core/providers.dart';
import '../controllers/reader_ui_controller.dart';
import '../providers/reader_engine_provider.dart';
import '../services/progress_persister.dart';
import '../widgets/reader_bottom_bar.dart';
import '../widgets/reader_error_view.dart';
import '../widgets/reader_scaffold.dart';
import '../widgets/toc_drawer.dart';
import '../widgets/typography_panel.dart';

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

class _ReaderBody extends ConsumerStatefulWidget {
  final ReaderEngine engine;

  const _ReaderBody({required this.engine});

  @override
  ConsumerState<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends ConsumerState<_ReaderBody> {
  ReaderEngine get engine => widget.engine;

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(readerUiControllerProvider);

    // typographyPanelOpen 由 _TypographyPanelTrigger 监听并弹出/收起 bottom sheet。
    return Scaffold(
      // 抽屉（左滑或图标触发）：TocDrawer。
      drawer: _buildTocDrawer(context),
      onDrawerChanged: (open) {
        // 用户从外部滑出/收起抽屉时同步 UI 状态。
        final notifier = ref.read(readerUiControllerProvider.notifier);
        if (open) {
          notifier.openTocDrawer();
        } else if (ui.tocDrawerOpen) {
          notifier.closeTocDrawer();
        }
      },
      body: Builder(
        builder: (innerContext) => Stack(
          children: [
            ReaderScaffold(
              content: engine.build(innerContext),
              title: _bookTitle(),
              onTapPrev: () => engine.previousSpine(),
              onTapNext: () => engine.nextSpine(),
              onBack: () => Navigator.of(innerContext).maybePop(),
              onOpenToc: () => Scaffold.of(innerContext).openDrawer(),
              onOpenTypography: () => ref
                  .read(readerUiControllerProvider.notifier)
                  .openTypographyPanel(),
            ),
            // 底栏始终可见，显示阅读进度。
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ReaderProgressBar(engine: engine),
            ),
            // typography 面板的触发器（不可见 listener）。
            _TypographyPanelTrigger(engine: engine),
          ],
        ),
      ),
    );
  }

  Widget _buildTocDrawer(BuildContext context) {
    final toc = engine.toc;
    if (toc == null) {
      return const Drawer(child: Center(child: Text('目录加载中…')));
    }
    return Drawer(
      child: TocDrawer(
        toc: toc,
        onSelect: (entry) async {
          await engine.gotoTocEntry(entry);
          // 跳转后关闭抽屉。
          if (context.mounted) {
            Scaffold.of(context).closeDrawer();
          }
        },
      ),
    );
  }

  /// 简化处理：暂未从 Book 元数据取得标题，显示统一占位。
  /// M2.5-2 接入 CFI restore 时，可在此传入对应的书名。
  String _bookTitle() => '阅读中';
}

/// 监听 [ReaderUiState.typographyPanelOpen] 并弹出/收起 TypographyPanel 的
/// 不可见 listener widget。
class _TypographyPanelTrigger extends ConsumerStatefulWidget {
  final ReaderEngine engine;

  const _TypographyPanelTrigger({required this.engine});

  @override
  ConsumerState<_TypographyPanelTrigger> createState() =>
      _TypographyPanelTriggerState();
}

class _TypographyPanelTriggerState
    extends ConsumerState<_TypographyPanelTrigger> {
  bool _sheetShown = false;

  void _handleStateChange(bool open) {
    if (open && !_sheetShown) {
      _sheetShown = true;
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => TypographyPanel(
          current: widget.engine.typography,
          onChanged: (settings) => widget.engine.setTypography(settings),
        ),
      ).whenComplete(() {
        // 用户通过下滑或点击外部关闭 sheet 时，同步 UI 状态。
        _sheetShown = false;
        ref.read(readerUiControllerProvider.notifier).closeTypographyPanel();
      });
    } else if (!open && _sheetShown) {
      _sheetShown = false;
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(readerUiControllerProvider,
        (previous, next) => _handleStateChange(next.typographyPanelOpen));
    return const SizedBox.shrink();
  }
}

/// 监听 [ReaderEngine.currentLocation$] 的 ReaderBottomBar 包装。
class _ReaderProgressBar extends StatefulWidget {
  final ReaderEngine engine;

  const _ReaderProgressBar({required this.engine});

  @override
  State<_ReaderProgressBar> createState() => _ReaderProgressBarState();
}

class _ReaderProgressBarState extends State<_ReaderProgressBar> {
  Locator? _current;

  @override
  void initState() {
    super.initState();
    widget.engine.currentLocation$.listen((loc) {
      if (mounted) setState(() => _current = loc);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReaderBottomBar(
      chapterTitle: _chapterTitle(_current),
      percent: _estimatePercent(_current),
    );
  }

  String? _chapterTitle(Locator? loc) {
    if (loc is EpubCfiLocator) return loc.chapterTitle;
    return null;
  }

  double _estimatePercent(Locator? loc) {
    if (loc is EpubCfiLocator) {
      return (loc.chapterIndex / 100).clamp(0.0, 1.0);
    }
    return 0.0;
  }
}
