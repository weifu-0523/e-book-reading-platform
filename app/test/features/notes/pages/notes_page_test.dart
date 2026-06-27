import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/core/providers.dart' show notesRepositoryProvider;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/notes/pages/notes_page.dart';

/// Fake [FilePicker] that returns a pre-configured directory path (or null to
/// simulate user cancel). Mirrors the T5 pattern — file_picker 8.3.7 uses FFI
/// on Windows, so [MethodChannel] mocks do not work and we must override
/// [FilePicker.platform] directly.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this._directoryPath);

  final String? _directoryPath;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async =>
      _directoryPath;

  // Unused in tests; provide no-op stubs.
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      null;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async =>
      null;

  @override
  Future<bool?> clearTemporaryFiles() async => false;
}

class _FakeNotesRepository implements NotesRepository {
  final List<Annotation> annotations;
  _FakeNotesRepository(this.annotations);

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.value(annotations);

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: '测试书名',
        summary: '',
        keyTakeaways: const [],
        annotations: annotations,
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<Annotation> annotations;
  // Reusable temp dir for export tests — created in setUp before testWidgets
  // runs, so the createTemp disk I/O happens outside the fake-async zone.
  late Directory exportTmpDir;

  setUp(() async {
    annotations = [
      Annotation(
        id: 'a1',
        bookNoteId: 'b1',
        locator: EpubRangeLocator(
            chapterIndex: 0,
            chapterTitle: '引言',
            startOffset: 0,
            endOffset: 1,
            quote: '引用 1'),
        quote: '引用 1',
        note: '笔记 1',
        color: HighlightColor.yellow,
        tags: const ['标签1'],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 20),
        updatedAt: DateTime(2026, 6, 27),
      ),
      Annotation(
        id: 'a2',
        bookNoteId: 'b1',
        locator: EpubRangeLocator(
            chapterIndex: 1,
            chapterTitle: '正文',
            startOffset: 0,
            endOffset: 1,
            quote: '引用 2'),
        quote: '引用 2',
        note: null,
        color: HighlightColor.red,
        tags: const [],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 21),
        updatedAt: DateTime(2026, 6, 27),
      ),
    ];
    exportTmpDir = await Directory.systemTemp.createTemp('m3.4_export_');
  });

  tearDown(() async {
    if (await exportTmpDir.exists()) {
      await exportTmpDir.delete(recursive: true);
    }
  });

  testWidgets('renders empty state when no annotations', (tester) async {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();
    expect(find.text('本书暂无高亮与笔记'), findsOneWidget);
  });

  testWidgets('groups by chapter and shows annotations', (tester) async {
    await tester.pumpWidget(_harness(annotations));
    await tester.pumpAndSettle();
    expect(find.text('引言'), findsWidgets);
    expect(find.text('正文'), findsWidgets);
    expect(find.text('引用 1'), findsOneWidget);
    expect(find.text('引用 2'), findsOneWidget);
  });

  testWidgets('tap annotation pushes reader route with locator extra',
      (tester) async {
    final pushed = <String?>{};
    final router = GoRouter(
      initialLocation: '/book/b1/notes',
      routes: [
        GoRoute(
            path: '/book/:id/notes',
            builder: (_, __) => ProviderScope(
                overrides: [
                  notesRepositoryProvider
                      .overrideWithValue(_FakeNotesRepository(annotations))
                ],
                child: const NotesPage(bookId: 'b1'))),
        GoRoute(
            path: '/book/:id',
            builder: (_, state) {
              pushed.add(state.extra.toString());
              return const Scaffold(body: Text('reader'));
            }),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引用 1'));
    await tester.pumpAndSettle();
    expect(pushed, isNotEmpty);
  });

  testWidgets('long-press opens context menu with edit/delete/copy',
      (tester) async {
    await tester.pumpWidget(_harness(annotations));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('引用 1'));
    await tester.pumpAndSettle();
    expect(find.text('编辑笔记'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('复制引用'), findsOneWidget);
    expect(find.text('复制 Markdown 片段'), findsOneWidget);
  });

  testWidgets('export success shows SnackBar with 打开文件夹 action',
      (tester) async {
    // file_picker 8.3.7 uses FFI on Windows — must override the singleton,
    // not the MethodChannel. Mirrors the T5 NoteFileWriter test pattern.
    FilePicker.platform = _FakeFilePicker(exportTmpDir.path);

    await tester.pumpWidget(_harness(annotations));
    await tester.pumpAndSettle();

    // _export awaits real disk I/O (File.writeAsString + provider.future).
    // Wrap tap+pump+delay in runAsync so the awaited chain can make
    // real-async progress; pump() after to render the SnackBar frame.
    await tester.binding.runAsync(() async {
      await tester.tap(find.byTooltip('导出 Markdown'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });
    await tester.pump();

    expect(find.textContaining('已保存'), findsOneWidget);
    expect(find.text('打开文件夹'), findsOneWidget);
  });
}

Widget _harness(List<Annotation> anns) {
  return ProviderScope(
    overrides: [
      notesRepositoryProvider.overrideWithValue(_FakeNotesRepository(anns))
    ],
    child: const MaterialApp(
      home: NotesPage(bookId: 'b1'),
    ),
  );
}
