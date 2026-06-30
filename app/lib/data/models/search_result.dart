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

import 'package:meta/meta.dart';

import '../../core/locator.dart';

@immutable
class SearchResult {
  final String bookId;
  final String bookTitle;
  final Locator locator;
  final String snippet;
  final int matchCount;

  const SearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.locator,
    required this.snippet,
    required this.matchCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId &&
          bookTitle == other.bookTitle &&
          locator == other.locator &&
          snippet == other.snippet &&
          matchCount == other.matchCount;

  @override
  int get hashCode =>
      Object.hash(bookId, bookTitle, locator, snippet, matchCount);
}
