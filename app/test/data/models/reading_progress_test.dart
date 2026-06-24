import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/reading_progress.dart';

void main() {
  test('ReadingProgress holds locator and percent', () {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 0.42,
      updatedAt: DateTime(2026, 6, 24),
    );
    expect(p.bookId, 'b1');
    expect(p.percent, 0.42);
  });

  test('percent clamped between 0 and 1', () {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 1.5,
      updatedAt: DateTime(2026, 6, 24),
    );
    expect(p.percent, 1.0);
  });
}
