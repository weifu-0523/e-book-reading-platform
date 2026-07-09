import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/services/book_import_service.dart';
import 'package:zhiyue/services/book_open_bridge.dart';

class _FakeBookImportService extends Mock implements BookImportService {}

class _MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('BookOpenBridge.isSupportedBookPath', () {
    test('accepts .epub paths', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/book.epub'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('C:\\Users\\me\\book.epub'), isTrue);
    });

    test('accepts .pdf paths', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/paper.pdf'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('C:\\docs\\paper.pdf'), isTrue);
    });

    test('accepts .md / .markdown / .mdown / .txt paths (M4.5)', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/notes.md'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/notes.markdown'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/notes.mdown'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/readme.txt'), isTrue);
    });

    test('rejects non-book extensions', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/image.png'), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/doc.docx'), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/archive.zip'), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/'), isFalse);
    });

    test('rejects empty / null-like paths', () {
      expect(BookOpenBridge.isSupportedBookPath(''), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('book'), isFalse);
    });

    test('case-insensitive on extensions', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/BOOK.EPUB'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/Paper.PDF'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/Notes.MD'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/Readme.TXT'), isTrue);
    });
  });

  group('BookOpenBridge.handlePath', () {
    late _FakeBookImportService importer;
    late _MockGoRouter router;
    late Directory tempDir;
    late File epubFile;

    setUp(() async {
      importer = _FakeBookImportService();
      router = _MockGoRouter();
      tempDir = await Directory.systemTemp.createTemp('bridge_test_');
      epubFile = File('${tempDir.path}/book.epub')
        ..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, 0x00]); // PK header
      registerFallbackValue(Uri.parse('/'));
      registerFallbackValue(File('${tempDir.path}/fallback.epub'));
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('imports and routes to /book/:id for supported path', () async {
      final book = Book(
        id: 'book-1',
        title: 'Test',
        author: null,
        format: BookFormat.epub,
        filePath: epubFile.path,
        fileHash: 'hash',
        fileSizeBytes: 5,
        coverPath: null,
        addedAt: DateTime.now(),
        lastReadAt: null,
      );
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenAnswer((_) async => ImportResult(book: book, isNew: true));

      await BookOpenBridge.handlePath(
        path: epubFile.path,
        importer: importer,
        router: router,
      );

      // importFile 应以 File 形式收到 path
      final captured = verify(() => importer.importFile(captureAny(),
              format: any(named: 'format')))
          .captured
          .single as File;
      expect(captured.path, epubFile.path);

      // router.push 应被调用到 /book/book-1
      verify(() => router.push('/book/book-1')).called(1);
    });

    test('skips silently on unsupported extension', () async {
      await BookOpenBridge.handlePath(
        path: '/tmp/image.png',
        importer: importer,
        router: router,
      );
      verifyNever(() => importer.importFile(any(),
          format: any(named: 'format')));
      verifyNever(() => router.push(any()));
    });

    test('does not crash when import throws', () async {
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenThrow(Exception('corrupt file'));

      // 不应抛出（silent failure，避免 native bridge 报错）
      await BookOpenBridge.handlePath(
        path: epubFile.path,
        importer: importer,
        router: router,
      );

      verifyNever(() => router.push(any()));
    });
  });

  group('BookOpenBridge.init', () {
    late _FakeBookImportService importer;
    late _MockGoRouter router;

    setUp(() {
      importer = _FakeBookImportService();
      router = _MockGoRouter();
    });

    test('handles Windows argv directly when path present', () async {
      const epubPath = '/tmp/win_arg_book.epub';
      // 模拟 import 成功
      final book = Book(
        id: 'b1',
        title: 'T',
        author: null,
        format: BookFormat.epub,
        filePath: epubPath,
        fileHash: 'h',
        fileSizeBytes: 1,
        coverPath: null,
        addedAt: DateTime.now(),
        lastReadAt: null,
      );
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenAnswer((_) async => ImportResult(book: book, isNew: true));

      // argv = ['--some-flag', '/tmp/win_arg_book.epub']，应过滤非白名单
      await BookOpenBridge.init(
        argv: ['--some-flag', epubPath],
        importer: importer,
        router: router,
      );

      verify(() => router.push('/book/b1')).called(1);
    });

    test('ignores argv with no supported path', () async {
      await BookOpenBridge.init(
        argv: ['--debug', '--enable-logging'],
        importer: importer,
        router: router,
      );
      verifyNever(() => importer.importFile(any(),
          format: any(named: 'format')));
    });
  });

  group('BookOpenBridge.handlePath error callback', () {
    late _FakeBookImportService importer;
    late _MockGoRouter router;
    late Directory tempDir;
    late File epubFile;
    late List<Object> capturedErrors;

    setUp(() async {
      importer = _FakeBookImportService();
      router = _MockGoRouter();
      capturedErrors = [];
      tempDir = await Directory.systemTemp.createTemp('bridge_err_');
      epubFile = File('${tempDir.path}/bad.epub')
        ..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, 0x00]);
      registerFallbackValue(Uri.parse('/'));
      registerFallbackValue(File('${tempDir.path}/fallback.epub'));
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('onError fires when import throws', () async {
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenThrow(Exception('corrupt epub'));

      await BookOpenBridge.handlePath(
        path: epubFile.path,
        importer: importer,
        router: router,
        options: BookOpenBridgeOptions(
          onError: (e, _) => capturedErrors.add(e),
        ),
      );

      expect(capturedErrors, hasLength(1));
      expect(capturedErrors.single, isA<Exception>());
      verifyNever(() => router.push(any()));
    });

    test('onError omitted (default) keeps old silent behavior', () async {
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenThrow(Exception('corrupt epub'));

      // 不传 options：与 M7 行为完全一致（静默忽略）
      await BookOpenBridge.handlePath(
        path: epubFile.path,
        importer: importer,
        router: router,
      );

      verifyNever(() => router.push(any()));
    });

    test('onError does not fire on unsupported extension', () async {
      await BookOpenBridge.handlePath(
        path: '/tmp/image.png',
        importer: importer,
        router: router,
        options: BookOpenBridgeOptions(
          onError: (e, _) => capturedErrors.add(e),
        ),
      );

      expect(capturedErrors, isEmpty);
      verifyNever(() => importer.importFile(any(),
          format: any(named: 'format')));
    });

    test('init propagates options.onError to cold-start path', () async {
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenThrow(Exception('corrupt'));

      // argv 中带支持路径 → handlePath 调用，options 应透传
      await BookOpenBridge.init(
        argv: ['/tmp/init_book.epub'],
        importer: importer,
        router: router,
        options: BookOpenBridgeOptions(
          onError: (e, _) => capturedErrors.add(e),
        ),
      );

      expect(capturedErrors, hasLength(1));
    });
  });
}
