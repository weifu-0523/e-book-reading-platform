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
    const a = LibraryState(books: [], searchQuery: 'x');
    const b = LibraryState(books: [], searchQuery: 'x');
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
