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

import 'package:flutter/foundation.dart';

import '../../../data/models/book.dart';
import 'library_mode.dart';
import 'sort_by.dart';
import 'view_mode.dart';

@immutable
class LibraryState {
  final List<Book> books;
  final Set<String> selectedIds;
  final Set<String> allTags;
  final Set<String> activeTagFilters;
  final ViewMode viewMode;
  final SortBy sortBy;
  final String searchQuery;
  final LibraryMode mode;
  final String? errorMessage;
  final bool isImporting;
  final double? importProgress;

  const LibraryState({
    this.books = const [],
    this.selectedIds = const {},
    this.allTags = const {},
    this.activeTagFilters = const {},
    this.viewMode = ViewMode.grid,
    this.sortBy = SortBy.recentlyRead,
    this.searchQuery = '',
    this.mode = LibraryMode.idle,
    this.errorMessage,
    this.isImporting = false,
    this.importProgress,
  });

  LibraryState copyWith({
    List<Book>? books,
    Set<String>? selectedIds,
    Set<String>? allTags,
    Set<String>? activeTagFilters,
    ViewMode? viewMode,
    SortBy? sortBy,
    String? searchQuery,
    LibraryMode? mode,
    Object? errorMessage = _sentinel,
    bool? isImporting,
    double? importProgress,
  }) {
    return LibraryState(
      books: books ?? this.books,
      selectedIds: selectedIds ?? this.selectedIds,
      allTags: allTags ?? this.allTags,
      activeTagFilters: activeTagFilters ?? this.activeTagFilters,
      viewMode: viewMode ?? this.viewMode,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
      mode: mode ?? this.mode,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      isImporting: isImporting ?? this.isImporting,
      importProgress: importProgress ?? this.importProgress,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibraryState &&
        listEquals(books, other.books) &&
        setEquals(selectedIds, other.selectedIds) &&
        setEquals(allTags, other.allTags) &&
        setEquals(activeTagFilters, other.activeTagFilters) &&
        viewMode == other.viewMode &&
        sortBy == other.sortBy &&
        searchQuery == other.searchQuery &&
        mode == other.mode &&
        errorMessage == other.errorMessage &&
        isImporting == other.isImporting &&
        importProgress == other.importProgress;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(books),
        Object.hashAll(selectedIds),
        Object.hashAll(allTags),
        Object.hashAll(activeTagFilters),
        viewMode,
        sortBy,
        searchQuery,
        mode,
        errorMessage,
        isImporting,
        importProgress,
      );
}
