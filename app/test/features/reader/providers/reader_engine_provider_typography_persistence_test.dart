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
  group('T3 - per-book typography persistence', () {
    test('T3.1 provider dispose calls saveForBook with current typography',
        () async {
      final fakeRepo = _RecordingBookTypographyRepository();

      final container = ProviderContainer(overrides: [
        bookRepositoryProvider.overrideWithValue(_StubBookRepository()),
        readingProgressRepositoryProvider.overrideWithValue(_NullProgressRepo()),
        bookTypographyRepositoryProvider.overrideWithValue(fakeRepo),
      ]);

      // Open the engine (will fail to open file, but engine object is created)
      final engine =
          await container.read(readerEngineForBookProvider('b1').future);

      // Engine exists and has default typography even if file failed to open
      expect(engine.typography, TypographySettings.defaults());

      // Dispose the container, which should trigger the provider's dispose hook
      container.dispose();
      // Allow async disposal to complete
      await Future<void>.delayed(Duration.zero);

      // Verify saveForBook was called exactly once with correct parameters
      expect(fakeRepo.saveCalls, hasLength(1));
      expect(fakeRepo.saveCalls.first.bookId, 'b1');
      expect(fakeRepo.saveCalls.first.settings, TypographySettings.defaults());
    });

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
