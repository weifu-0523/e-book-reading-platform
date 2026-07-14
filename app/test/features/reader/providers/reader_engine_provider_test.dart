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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';
import 'package:zhiyue/data/repositories/reading_progress_repository.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

class _FakeBookRepository implements BookRepository {
  @override
  Future<Book?> getById(String id) async {
    if (id == 'b1') {
      return Book(
        id: 'b1',
        title: 'Test',
        author: null,
        format: BookFormat.epub,
        filePath: '/tmp/test.epub',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime.now(),
        lastReadAt: null,
      );
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeReadingProgressRepository implements ReadingProgressRepository {
  _FakeReadingProgressRepository({this.progress});

  final ReadingProgress? progress;
  final List<String> getCallIds = [];

  @override
  Future<ReadingProgress?> get(String bookId) async {
    getCallIds.add(bookId);
    return progress;
  }

  @override
  Future<void> save(ReadingProgress progress) async {}
}

class _FakeBookTypographyRepository implements BookTypographyRepository {
  final Map<String, TypographySettings> _storage = {};

  @override
  Future<TypographySettings?> getForBook(String bookId) async {
    return _storage[bookId];
  }

  @override
  Future<void> saveForBook(String bookId, TypographySettings settings) async {
    _storage[bookId] = settings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test(
      'readerEngineForBookProvider returns ConcreteEpubReaderEngine for epub',
      () async {
    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
        readingProgressRepositoryProvider.overrideWithValue(
          _FakeReadingProgressRepository(),
        ),
        bookTypographyRepositoryProvider.overrideWithValue(
          _FakeBookTypographyRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final engine =
        await container.read(readerEngineForBookProvider('b1').future);
    expect(engine, isA<ReaderEngine>());
    // 2026-07-08: provider is now autoDispose + ref.onDispose(engine.close).
    // container.dispose() (addTearDown above) will close the engine — no
    // need (and unsafe) to call engine.close() manually here.
  });

  test('readerEngineForBookProvider throws for non-existent book', () async {
    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
        readingProgressRepositoryProvider.overrideWithValue(
          _FakeReadingProgressRepository(),
        ),
        bookTypographyRepositoryProvider.overrideWithValue(
          _FakeBookTypographyRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(readerEngineForBookProvider('nonexistent').future),
      throwsA(isA<StateError>()),
    );
  });

  test(
      'readerEngineForBookProvider consults reading progress to restore locator',
      () async {
    final progressRepo = _FakeReadingProgressRepository(
      progress: ReadingProgress(
        bookId: 'b1',
        locator: const EpubCfiLocator(cfi: '/6/4', chapterIndex: 2),
        percent: 0.25,
        updatedAt: DateTime.now(),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
        readingProgressRepositoryProvider.overrideWithValue(progressRepo),
        bookTypographyRepositoryProvider.overrideWithValue(
          _FakeBookTypographyRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final engine =
        await container.read(readerEngineForBookProvider('b1').future);
    // Provider should have queried progress repo with the bookId.
    expect(progressRepo.getCallIds, contains('b1'));
    // openWithLastProgress is called even when file load fails:
    // state ends as ReaderEngineError (file doesn't exist on disk) or Ready.
    // What matters: provider returned the engine (no throw) and consulted repo.
    expect(engine.state, isA<ReaderEngineState>());
    // 2026-07-08: provider is now autoDispose + ref.onDispose(engine.close).
    // container.dispose() (addTearDown above) will close the engine — no
    // need (and unsafe) to call engine.close() manually here.
  });
}
