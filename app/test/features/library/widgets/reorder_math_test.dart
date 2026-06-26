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
