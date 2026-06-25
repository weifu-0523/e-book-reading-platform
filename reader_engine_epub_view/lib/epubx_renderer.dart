import 'dart:async';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/rendering/renderer.dart';

/// epubx + flutter_widget_from_html 实现的 [EpubRenderer]。
///
/// 持有 [EpubBook]，自管 [ReaderEngineState] 状态机。
/// 章节渲染（build）、位置流（currentLocation$）、跳转（gotoLocator）
/// 在 Task 12 实现 —— 此版本是骨架。
class EpubxRenderer implements EpubRenderer {
  EpubxRenderer();

  final _stateController = StreamController<ReaderEngineState>.broadcast();
  final _locationController = StreamController<Locator>.broadcast();

  EpubBook? _book;
  int _currentChapterIndex = 0;
  TypographySettings _typography = TypographySettings.defaults();  // ⚠️ NOT const (M1 factory)
  PaginationMode _paginationMode = PaginationMode.paged;

  ReaderEngineState _state = const ReaderEngineUnloaded();

  ReaderEngineState get state => _state;

  Stream<ReaderEngineState> get state$ async* {
    yield _state;  // emit current state immediately to new subscriber
    yield* _stateController.stream;  // forward future emissions
  }

  @override
  Stream<Locator> get currentLocation$ => _locationController.stream;

  /// 当前持有的书 —— Task 12+ 用，外部只读访问。
  EpubBook? get book => _book;

  /// 当前章节索引 —— Task 12+ 用。
  int get currentChapterIndex => _currentChapterIndex;

  void _setState(ReaderEngineState next) {
    _state = next;
    _stateController.add(next);
  }

  @override
  Future<void> openFile(String filePath) async {
    _setState(const ReaderEngineLoading());
    try {
      final bytes = await File(filePath).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      _book = book;
      _currentChapterIndex = 0;
      _setState(const ReaderEngineReady());
    } catch (e, st) {
      debugPrint('EpubxRenderer.openFile failed: $filePath\n$e\n$st');
      _setState(ReaderEngineError(message: '$e', cause: e));  // ⚠️ plan said `cause: e` only — but message is required
    }
  }

  // ---- 以下方法在 Task 12 实现，此处 stub ----

  @override
  Future<TableOfContents> get toc async => TableOfContents.empty();

  @override
  Future<void> gotoLocator(Locator locator) async {
    // Task 12 实现
  }

  @override
  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
    // Task 19 实现 CSS-like 注入
  }

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {
    _paginationMode = mode;
    // Task 12-13 实现：重建 widget tree
  }

  @override
  Widget build(BuildContext context) {
    // Task 12 实现：flutter_widget_from_html 的 HtmlWidget
    return const SizedBox.shrink();
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _locationController.close();
  }
}
