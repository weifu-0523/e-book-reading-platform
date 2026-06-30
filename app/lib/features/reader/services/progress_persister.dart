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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/reading_progress_repository.dart';

/// 进度持久化服务。
///
/// 行为：
/// - 防抖：连续位置变化合并，最后一次为准
/// - distinct：相同 CFI 不重复写
/// - 静默失败：磁盘 IO 异常不抛出，仅 log
class ProgressPersister {
  ProgressPersister({
    required this.bookId,
    required this.repository,
    required this.source,
    this.debounceMs = 500,
  });

  final String bookId;
  final ReadingProgressRepository repository;
  final Stream<Locator> source;
  final int debounceMs;

  StreamSubscription<Locator>? _sub;
  Timer? _debounce;
  Locator? _lastEmitted;
  Locator? _lastPersisted;
  bool _alive = true;

  bool get isAlive => _alive;

  void start() {
    _sub = source.listen(_onLocation);
  }

  void _onLocation(Locator locator) {
    if (locator == _lastEmitted) return;
    _lastEmitted = locator;

    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: debounceMs), () async {
      final loc = _lastEmitted;
      if (loc == null || loc == _lastPersisted) return;
      try {
        await repository.save(ReadingProgress(
          bookId: bookId,
          locator: loc,
          percent: _estimatePercent(loc),
          updatedAt: DateTime.now(),
        ));
        _lastPersisted = loc;
      } catch (e, st) {
        // 静默失败（spec §5.2）
        debugPrint('ProgressPersister save failed: $e\n$st');
      }
    });
  }

  double _estimatePercent(Locator locator) {
    // 粗略估算：chapterIndex / 100。M3 用真实 spine 长度。
    if (locator is EpubCfiLocator) {
      return (locator.chapterIndex / 100).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  void dispose() {
    _alive = false;
    _debounce?.cancel();
    _sub?.cancel();
  }
}
