import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/features/library/widgets/batch_export_dialog.dart';
import 'package:zhiyue/features/notes/services/vault_exporter.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

Book _book(String id, String title) => Book(
      id: id,
      title: title,
      author: null,
      format: BookFormat.epub,
      filePath: '/$id.epub',
      fileHash: 'h_$id',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );

BookNote _note(String bookId, String title) => BookNote(
      id: 'n_$bookId',
      bookId: bookId,
      title: '《$title》读书笔记',
      summary: 's',
      keyTakeaways: const [],
      annotations: const [],
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 30),
    );

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

/// Windows sometimes holds a brief exclusive lock on freshly written files
/// (Defender / indexing). Retry deletion a few times so tearDown doesn't
/// mask the real test result with a `PathAccessException`.
void _deleteTempDir(Directory dir) {
  for (var i = 0; i < 10; i++) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      return;
    } on PathAccessException {
      sleep(const Duration(milliseconds: 50));
    }
  }
  if (dir.existsSync()) dir.deleteSync(recursive: true);
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('batch_export_test');
  });

  tearDown(() {
    _deleteTempDir(tempDir);
  });

  testWidgets('shows progress bar and cancel button during export',
      (tester) async {
    final books = [_book('b1', 'A'), _book('b2', 'B')];
    final notes = {'b1': _note('b1', 'A'), 'b2': _note('b2', 'B')};
    // The dialog kicks off VaultExporter from initState via
    // addPostFrameCallback, and the exporter awaits real disk I/O
    // (File.writeAsString). Under flutter_test's FakeAsync these awaited
    // completions don't progress with pump() alone — pumpWidget + pump must
    // be driven from inside binding.runAsync so the post-frame callback
    // runs in the real-async Zone (mirrors the notes_page_test pattern).
    await tester.binding.runAsync(() async {
      await tester.pumpWidget(_wrap(BatchExportDialog(
        targetDirPath: tempDir.path,
        books: books,
        notesByBookId: notes,
        onCompleted: (_) {},
      )));
      await tester.pump();
      // Two books → first file write resolves here so the dialog is visibly
      // mid-export. Short delay is enough; we don't need full completion.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('completes and calls onCompleted with non-empty result',
      (tester) async {
    VaultExportResult? captured;
    final books = [_book('b1', 'A')];
    final notes = {'b1': _note('b1', 'A')};
    await tester.binding.runAsync(() async {
      await tester.pumpWidget(_wrap(BatchExportDialog(
        targetDirPath: tempDir.path,
        books: books,
        notesByBookId: notes,
        onCompleted: (r) => captured = r,
      )));
      await tester.pump();
      // Poll briefly so disk writes + onCompleted resolve reliably across
      // CI / AV-scan jitter.
      for (var i = 0; i < 30 && captured == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.booksExported, 1);
  });
}
