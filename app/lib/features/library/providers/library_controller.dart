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
    // 持久化的 sortBy 可能与默认值不同，需要重新订阅才能让 repository 按新顺序输出。
    _resubscribe();
  }

  void _subscribeToBooks() {
    _resubscribe();
  }

  /// 用当前 state.sortBy / state.searchQuery / state.activeTagFilters 重新订阅 watchAll。
  /// 在 _hydrateFromSettings、setSortBy、setSearchQuery 的 debounce 回调与
  /// toggleTagFilter 之后调用，使过滤/排序参数真正传递到 repository 层
  /// （否则它们仅写入 state 而 books 列表不变）。
  void _resubscribe() {
    _booksSub?.cancel();
    final query = state.searchQuery.isEmpty ? null : state.searchQuery;
    final tags = state.activeTagFilters.isEmpty ? null : state.activeTagFilters;
    _booksSub = _bookRepository
        .watchAll(
          sortBy: state.sortBy,
          searchQuery: query,
          tagFilters: tags,
        )
        .listen((books) async {
      final allTags = await _bookTagsLookup.allTags();
      if (!mounted) return;
      state = state.copyWith(books: books, allTags: allTags);
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
    _resubscribe();
  }

  Future<void> setSearchQuery(String query) async {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      state = state.copyWith(searchQuery: query);
      _resubscribe();
    });
  }

  Future<void> toggleTagFilter(String tag) async {
    final next = Set<String>.from(state.activeTagFilters);
    if (!next.add(tag)) next.remove(tag);
    state = state.copyWith(activeTagFilters: next);
    _resubscribe();
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
