// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';

/// 排版即时持久化服务。
///
/// 行为（参照 [ProgressPersister]）：
/// - 即时落盘：用户每次调字号/行距/字体等，500ms 后写入 [BookTypographyRepository]，
///   不依赖 ref.onDispose 或进程退出时的清理钩子。
/// - 防抖：连续变化合并，最后一次为准。
/// - distinct：相同 [TypographySettings] 不重复写（[TypographySettings] 已重写 ==）。
/// - 静默失败：磁盘 IO 异常不抛出，仅 log。
///
/// 背景：main.dart 的 _WindowCloseHandler.onWindowClose 调 exit(0) 同步终止
/// Dart isolate，会跳过所有 dispose 回调 + 截断所有 pending Future。原来在
/// reader_engine_provider.ref.onDispose 里 fire-and-forget 的 saveForBook 因此
/// 必然在关窗时丢失。改为订阅 engine.state$（setTypography 会触发 emit，见
/// epubx_renderer.dart:958），即时落盘避免依赖 dispose。
class TypographyPersister {
  TypographyPersister({
    required this.bookId,
    required this.repository,
    required this.stateSource,
    required this.typographyGetter,
    this.debounceMs = 500,
  });

  final String bookId;
  final BookTypographyRepository repository;
  final Stream<ReaderEngineState> stateSource;
  final TypographySettings Function() typographyGetter;
  final int debounceMs;

  StreamSubscription<ReaderEngineState>? _sub;
  Timer? _debounce;
  TypographySettings? _lastEmitted;
  TypographySettings? _lastPersisted;
  bool _alive = true;

  bool get isAlive => _alive;

  void start() {
    _sub = stateSource.listen(_onState);
  }

  void _onState(ReaderEngineState state) {
    if (!_alive) return;
    final current = typographyGetter();
    if (current == _lastEmitted) return;
    _lastEmitted = current;

    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: debounceMs), () async {
      final settings = _lastEmitted;
      if (settings == null || settings == _lastPersisted) return;
      try {
        await repository.saveForBook(bookId, settings);
        _lastPersisted = settings;
      } catch (e, st) {
        debugPrint('TypographyPersister save failed: $e\n$st');
      }
    });
  }

  void dispose() {
    _alive = false;
    _debounce?.cancel();
    _sub?.cancel();
  }
}
