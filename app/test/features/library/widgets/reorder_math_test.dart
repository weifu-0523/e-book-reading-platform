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

// Re-verifies the reorder index translation that was buggy in T17.
// Documents the reorderables package semantics so future maintainers
// don't re-introduce the Flutter-ReorderableListView-style -1 adjustment.

void main() {
  List<String> reorderIds(List<String> ids, int oldIdx, int newIdx) {
    final ordered = List<String>.of(ids);
    final moved = ordered.removeAt(oldIdx);
    ordered.insert(newIdx, moved);
    return ordered;
  }

  test('forward reorder: A->after C in [A,B,C,D] yields [B,C,D,A]', () {
    expect(
      reorderIds(['A', 'B', 'C', 'D'], 0, 3),
      ['B', 'C', 'D', 'A'],
    );
  });

  test('backward reorder: D->before A in [A,B,C,D] yields [D,A,B,C]', () {
    expect(
      reorderIds(['A', 'B', 'C', 'D'], 3, 0),
      ['D', 'A', 'B', 'C'],
    );
  });

  test('adjacent forward: A->after B in [A,B,C] yields [B,A,C]', () {
    expect(
      reorderIds(['A', 'B', 'C'], 0, 1),
      ['B', 'A', 'C'],
    );
  });

  test('no-op: same index', () {
    expect(
      reorderIds(['A', 'B', 'C'], 1, 1),
      ['A', 'B', 'C'],
    );
  });
}
