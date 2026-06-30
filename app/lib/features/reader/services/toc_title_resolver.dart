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

import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';

/// Flattens a [TableOfContents] into a `{chapterIndex: title}` map.
///
/// Walk algorithm: depth-first traversal. For each [TocEntry]:
/// - If `entry.locator is EpubCfiLocator`, register
///   `loc.chapterIndex -> entry.title`.
/// - Skip non-EpubCfiLocator entries (e.g., EpubRangeLocator).
/// - Duplicate chapterIndex: depth-first first-wins (matches reader order).
class TocTitleResolver {
  static Map<int, String> resolve(TableOfContents? toc) {
    if (toc == null) return {};
    final map = <int, String>{};
    void walk(List<TocEntry> entries) {
      for (final e in entries) {
        final loc = e.locator;
        if (loc is EpubCfiLocator) {
          map.putIfAbsent(loc.chapterIndex, () => e.title);
        }
        walk(e.children);
      }
    }

    walk(toc.entries);
    return map;
  }
}
