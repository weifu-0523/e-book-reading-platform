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

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/services/book_import_service.dart';
import 'package:zhiyue/services/book_open_bridge.dart';

class _MockImporter extends Mock implements BookImportService {}

class _MockGoRouter extends Mock implements GoRouter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockImporter importer;
  late _MockGoRouter router;

  setUp(() {
    importer = _MockImporter();
    router = _MockGoRouter();
    registerFallbackValue(File('/tmp/fallback.epub'));
  });

  tearDown(() {
    // Reset mock handler on the argv channel between tests so they don't
    // leak into each other.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.zhiyue.bookopen.argv'), null);
  });

  /// Helper: stub [BookImportService.importFile] to return a fake [Book] with
  /// the given id, for the warm-start tests where import always succeeds.
  Book _stubImport(String bookId) {
    final book = Book(
      id: bookId,
      title: 'T',
      author: null,
      format: BookFormat.epub,
      filePath: '/tmp/warm.epub',
      fileHash: 'h',
      fileSizeBytes: 4,
      coverPath: null,
      addedAt: DateTime.now(),
      lastReadAt: null,
    );
    when(() => importer.importFile(any(), format: any(named: 'format')))
        .thenAnswer((_) async => ImportResult(book: book, isNew: true));
    return book;
  }

  test('Windows popPendingArgv returns cached epub path → triggers import',
      () async {
    // Real temp .epub with ZIP magic so isSupportedBookPath accepts it.
    final tempDir =
        Directory.systemTemp.createTempSync('book_open_bridge_warm_');
    addTearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final epubPath = '${tempDir.path}/book.epub';
    await File(epubPath).writeAsBytes([0x50, 0x4B, 0x03, 0x04]); // PK\x03\x04

    final book = _stubImport('warm-1');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.zhiyue.bookopen.argv'), (call) async {
      if (call.method == 'popPendingArgv') return epubPath;
      return null;
    });

    await BookOpenBridge.init(
      argv: const [],
      importer: importer,
      router: router,
    );

    verify(() => importer.importFile(any(), format: any(named: 'format')))
        .called(greaterThanOrEqualTo(1));
    verify(() => router.push('/book/${book.id}')).called(1);
  });

  test('popPendingArgv empty → no import attempted', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.zhiyue.bookopen.argv'), (call) async {
      if (call.method == 'popPendingArgv') return '';
      return null;
    });

    await BookOpenBridge.init(
      argv: const [],
      importer: importer,
      router: router,
    );

    verifyNever(() => importer.importFile(any(), format: any(named: 'format')));
    verifyNever(() => router.push(any()));
  });

  test('popPendingArgv with unsupported extension → no import', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.zhiyue.bookopen.argv'), (call) async {
      if (call.method == 'popPendingArgv') return 'C:\\notes.docx';
      return null;
    });

    await BookOpenBridge.init(
      argv: const [],
      importer: importer,
      router: router,
    );

    verifyNever(() => importer.importFile(any(), format: any(named: 'format')));
    verifyNever(() => router.push(any()));
  });
}
