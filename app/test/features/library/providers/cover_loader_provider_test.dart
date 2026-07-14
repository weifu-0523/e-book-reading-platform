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

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/providers/cover_loader_provider.dart';
import 'package:zhiyue/features/sync/providers/sync_controller.dart';
import 'package:zhiyue/services/sync/book_file_sync_service.dart';

import '../../../fakes/fake_book_repository.dart';

class _MockSyncController extends Mock implements SyncController {}

void main() {
  late FakeBookRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeBookRepository();
    container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWith((ref) => fakeRepo),
      ],
    );
    registerFallbackValue(''); // for any() String args
  });
  tearDown(() => container.dispose());

  test('coverLoaderProvider returns null when book not found', () async {
    final file = await container.read(coverLoaderProvider('missing').future);
    expect(file, isNull);
  });

  test('coverLoaderProvider returns null when book.coverPath is null', () async {
    await fakeRepo.save(_fakeBook('b1', coverPath: null));
    final file = await container.read(coverLoaderProvider('b1').future);
    expect(file, isNull);
  });

  test('coverLoaderProvider returns File when cover exists on disk', () async {
    // 写入真实临时文件
    final tempDir = await Directory.systemTemp.createTemp('cover_loader_test_');
    final coverFile = File('${tempDir.path}/cover.png')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    await fakeRepo.save(_fakeBook('b2', coverPath: coverFile.path));
    final file = await container.read(coverLoaderProvider('b2').future);
    expect(file, isNotNull);
    expect(file!.path, coverFile.path);
  });

  test('coverLoaderProvider returns null when coverPath file is missing on disk',
      () async {
    await fakeRepo.save(_fakeBook('b3', coverPath: '/nonexistent/cover.png'));
    final file = await container.read(coverLoaderProvider('b3').future);
    expect(file, isNull);
  });

  // T4 (2026-07-13): sentinel cover_path triggers lazy download via
  // SyncController.downloadCoverFile.
  group('cover sync sentinel (T4)', () {
    late _MockSyncController mockController;
    late ProviderContainer sentinelContainer;

    setUp(() {
      mockController = _MockSyncController();
      sentinelContainer = ProviderContainer(
        overrides: [
          bookRepositoryProvider.overrideWith((ref) => fakeRepo),
          syncControllerProvider.overrideWith((ref) => mockController),
        ],
      );
    });
    tearDown(() => sentinelContainer.dispose());

    test('sentinel triggers downloadCoverFile + returns File on success',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('cover_sent_ok_');
      final coverFile = File('${tempDir.path}/c.png')..writeAsBytesSync([9]);
      addTearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      await fakeRepo.save(_fakeBook('b-sent-ok',
          coverPath: BookFileSyncService.needsCoverDownloadSentinel));
      when(() => mockController.downloadCoverFile('b-sent-ok'))
          .thenAnswer((_) async {
        // Simulate drift DSL UPDATE cover_path = localPath.
        await fakeRepo.updateCoverPath('b-sent-ok', coverFile.path);
        return true;
      });

      final file =
          await sentinelContainer.read(coverLoaderProvider('b-sent-ok').future);
      expect(file, isNotNull);
      expect(file!.path, coverFile.path);
      verify(() => mockController.downloadCoverFile('b-sent-ok')).called(1);
    });

    test('returns null when downloadCoverFile fails (network error)', () async {
      await fakeRepo.save(_fakeBook('b-fail',
          coverPath: BookFileSyncService.needsCoverDownloadSentinel));
      when(() => mockController.downloadCoverFile('b-fail'))
          .thenAnswer((_) async => false);

      final file =
          await sentinelContainer.read(coverLoaderProvider('b-fail').future);
      expect(file, isNull);
    });

    test('returns null when sentinel cleared to NULL on 404', () async {
      await fakeRepo.save(_fakeBook('b-404',
          coverPath: BookFileSyncService.needsCoverDownloadSentinel));
      when(() => mockController.downloadCoverFile('b-404')).thenAnswer((_) async {
        // Simulate 404 path: cover_path cleared to NULL.
        await fakeRepo.updateCoverPath('b-404', null);
        return true;
      });

      final file =
          await sentinelContainer.read(coverLoaderProvider('b-404').future);
      expect(file, isNull);
    });
  });
}

Book _fakeBook(String id, {String? coverPath}) => Book(
      id: id,
      title: id,
      author: null,
      format: BookFormat.epub,
      filePath: '/$id.epub',
      fileHash: 'h-$id',
      fileSizeBytes: 100,
      coverPath: coverPath,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
