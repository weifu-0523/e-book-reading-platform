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

import '../../../data/models/annotation.dart';

class AnnotationSearchQuery {
  final String keyword;
  final List<String> tags;
  final HighlightColor? color;

  const AnnotationSearchQuery({
    required this.keyword,
    this.tags = const [],
    this.color,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnnotationSearchQuery) return false;
    if (keyword != other.keyword || color != other.color) return false;
    if (tags.length != other.tags.length) return false;
    return tags.every(other.tags.contains);
  }

  @override
  int get hashCode =>
      Object.hash(keyword, Object.hashAllUnordered(tags), color);
}
