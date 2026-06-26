import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/book_tags_dao.dart';
import '../../../data/models/book.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../models/library_mode.dart';
import '../models/library_state.dart';
import '../models/sort_by.dart';
import '../models/view_mode.dart';

/// Narrow port over [BookTagsDao] for testability.
/// Only exposes what [LibraryController] needs.
abstract class BookTagsLookup {
  Future<Set<String>> allTags();
}

/// Adapter so the real [BookTagsDao] (which doesn't directly implement
/// [BookTagsLookup]) can be passed to [LibraryController].
class BookTagsDaoLookupAdapter implements BookTagsLookup {
  final BookTagsDao dao;
  BookTagsDaoLookupAdapter(this.dao);

  @override
  Future<Set<String>> allTags() => dao.allTags();
}

class LibraryController extends StateNotifier<LibraryState> {
  final BookRepository _bookRepository;
  final BookTagsLookup _bookTagsLookup;
  final SettingsRepository _settingsRepository;
  StreamSubscription<List<Book>>? _booksSub;
  Timer? _searchDebounce;

  /// Hydration future. Explicit setters chain onto this so they cannot be
  /// clobbered by a late-arriving settings read from the constructor.
  Future<void> _hydrated = Future<void>.value();

  static const _keyViewMode = 'library.viewMode';
  static const _keySortBy = 'library.sortBy';

  LibraryController({
    required BookRepository bookRepository,
    required BookTagsLookup bookTagsLookup,
    required SettingsRepository settingsRepository,
  })  : _bookRepository = bookRepository,
        _bookTagsLookup = bookTagsLookup,
        _settingsRepository = settingsRepository,
        super(const LibraryState()) {
    _hydrated = _hydrateFromSettings();
    _subscribeToBooks();
  }

  Future<void> _hydrateFromSettings() async {
    final viewModeStr =
        await _settingsRepository.get<String>(_keyViewMode, 'grid');
    final sortByStr =
        await _settingsRepository.get<String>(_keySortBy, 'recentlyRead');
    if (!mounted) return;
    state = state.copyWith(
      viewMode: viewModeStr == 'list' ? ViewMode.list : ViewMode.grid,
      sortBy: SortBy.values.firstWhere(
        (s) => s.name == sortByStr,
        orElse: () => SortBy.recentlyRead,
      ),
    );
  }

  void _subscribeToBooks() {
    _booksSub = _bookRepository.watchAll().listen((books) async {
      final tags = await _bookTagsLookup.allTags();
      if (!mounted) return;
      state = state.copyWith(books: books, allTags: tags);
    });
  }

  Future<void> setViewMode(ViewMode mode) async {
    await _hydrated;
    if (!mounted) return;
    state = state.copyWith(viewMode: mode);
    await _settingsRepository.set<String>(_keyViewMode, mode.name);
  }

  Future<void> setSortBy(SortBy sortBy) async {
    await _hydrated;
    if (!mounted) return;
    state = state.copyWith(sortBy: sortBy);
    await _settingsRepository.set<String>(_keySortBy, sortBy.name);
  }

  Future<void> setSearchQuery(String query) async {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      state = state.copyWith(searchQuery: query);
    });
  }

  Future<void> toggleTagFilter(String tag) async {
    final next = Set<String>.from(state.activeTagFilters);
    if (!next.add(tag)) next.remove(tag);
    state = state.copyWith(activeTagFilters: next);
  }

  void enterSelectionMode(String initialBookId) {
    state = state.copyWith(
      mode: LibraryMode.selecting,
      selectedIds: {initialBookId},
    );
  }

  void toggleSelection(String bookId) {
    final next = Set<String>.from(state.selectedIds);
    if (!next.add(bookId)) next.remove(bookId);
    state = state.copyWith(selectedIds: next);
  }

  /// 选中所有给定 id（通常由 UI 传入当前 books 的全部 id）。
  /// 直接替换 selectedIds，不进入选择模式由调用方负责。
  void selectAll(Iterable<String> ids) {
    state = state.copyWith(selectedIds: Set<String>.of(ids));
  }

  void exitSelectionMode() {
    state = state.copyWith(
      mode: LibraryMode.idle,
      selectedIds: const {},
    );
  }

  Future<void> deleteBook(String bookId) async {
    await _bookRepository.delete(bookId);
  }

  Future<void> batchDelete() async {
    if (state.selectedIds.isEmpty) return;
    final ids = Set<String>.from(state.selectedIds);
    await _bookRepository.deleteBooks(ids);
    exitSelectionMode();
  }

  Future<void> setManualSortOrder(List<String> orderedBookIds) async {
    for (var i = 0; i < orderedBookIds.length; i++) {
      await _bookRepository.setSortOrder(
        bookId: orderedBookIds[i],
        sortOrder: i,
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _booksSub?.cancel();
    super.dispose();
  }
}
