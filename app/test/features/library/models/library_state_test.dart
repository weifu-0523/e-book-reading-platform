import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/models/library_state.dart';
import 'package:zhiyue/features/library/models/view_mode.dart';
import 'package:zhiyue/features/library/models/library_mode.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';

void main() {
  test('LibraryState defaults', () {
    const s = LibraryState();
    expect(s.books, isEmpty);
    expect(s.selectedIds, isEmpty);
    expect(s.viewMode, ViewMode.grid);
    expect(s.sortBy, SortBy.recentlyRead);
    expect(s.mode, LibraryMode.idle);
    expect(s.isImporting, isFalse);
  });

  test('copyWith preserves unmodified fields', () {
    final s = const LibraryState().copyWith(viewMode: ViewMode.list);
    expect(s.viewMode, ViewMode.list);
    expect(s.sortBy, SortBy.recentlyRead); // unchanged
  });

  test('equality covers all fields', () {
    final a = LibraryState(books: [], searchQuery: 'x');
    final b = LibraryState(books: [], searchQuery: 'x');
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('copyWith errorMessage can be cleared to null', () {
    final s1 = const LibraryState().copyWith(errorMessage: 'err');
    expect(s1.errorMessage, 'err');
    final s2 = s1.copyWith(errorMessage: null);
    expect(s2.errorMessage, isNull);
  });
}
