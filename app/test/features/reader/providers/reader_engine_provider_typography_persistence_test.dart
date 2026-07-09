// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';
import 'package:zhiyue/data/repositories/reading_progress_repository.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

/// Records calls to saveForBook for verification.
class _SaveCall {
  final String bookId;
  final TypographySettings settings;

  _SaveCall(this.bookId, this.settings);
}

/// Fake BookTypographyRepository that records saveForBook calls.
///
/// NOTE: After T3 removed the fire-and-forget dispose-time save, saveCalls is
/// no longer asserted by any test in this file. The fake is retained because
/// _applyPersistedTypography still uses getForBook on engine open.
class _RecordingBookTypographyRepository implements BookTypographyRepository {
  final List<_SaveCall> saveCalls = [];
  TypographySettings? getForBookReturnValue;

  @override
  Future<TypographySettings?> getForBook(String bookId) async {
    return getForBookReturnValue;
  }

  @override
  Future<void> saveForBook(String bookId, TypographySettings settings) async {
    saveCalls.add(_SaveCall(bookId, settings));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Stub BookRepository that returns a fake Book.
class _StubBookRepository implements BookRepository {
  @override
  Future<Book?> getById(String id) async => Book(
        id: id,
        title: 'T',
        author: null,
        format: BookFormat.epub,
        filePath: '/tmp/nonexistent.epub',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime.now(),
        lastReadAt: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Stub ReadingProgressRepository that returns null (no progress).
class _NullProgressRepo implements ReadingProgressRepository {
  @override
  Future<ReadingProgress?> get(String bookId) async => null;

  @override
  Future<void> save(ReadingProgress progress) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  group('T3 - per-book typography load on open', () {
    test('T3.2 first-time open (no override) → engine at defaults', () async {
      final fakeRepo = _RecordingBookTypographyRepository()
        ..getForBookReturnValue = null;

      final container = ProviderContainer(overrides: [
        bookRepositoryProvider.overrideWithValue(_StubBookRepository()),
        readingProgressRepositoryProvider.overrideWithValue(_NullProgressRepo()),
        bookTypographyRepositoryProvider.overrideWithValue(fakeRepo),
      ]);
      addTearDown(container.dispose);

      final engine =
          await container.read(readerEngineForBookProvider('b1').future);

      // First-time open with no override should use defaults
      expect(engine.typography, TypographySettings.defaults());
    });
  });
}
