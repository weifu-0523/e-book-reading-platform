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
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/bookmarks/services/bookmark_markdown_exporter.dart';

BookmarkEntry _entry({
  required String id,
  required String label,
  String? note,
  required DateTime createdAt,
}) =>
    BookmarkEntry(
      id: id,
      bookId: 'b1',
      locatorJson: '{}',
      label: label,
      note: note,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

void main() {
  group('BookmarkMarkdownExporter.exportSingle', () {
    test('label + note + 创建时间', () {
      final md = BookmarkMarkdownExporter.exportSingle(_entry(
        id: 'bm1',
        label: '开头',
        note: '重要',
        createdAt: DateTime(2026, 7, 3, 9, 30),
      ));
      expect(md, '# 开头\n\n重要\n\n> 创建于 2026-07-03');
    });

    test('note 为空时省略备注段', () {
      final md = BookmarkMarkdownExporter.exportSingle(_entry(
        id: 'bm2',
        label: '第 5 页',
        note: null,
        createdAt: DateTime(2026, 7, 3),
      ));
      expect(md, '# 第 5 页\n\n> 创建于 2026-07-03');
    });

    test('note 为空字符串时也省略备注段', () {
      final md = BookmarkMarkdownExporter.exportSingle(_entry(
        id: 'bm3',
        label: '标记',
        note: '',
        createdAt: DateTime(2026, 1, 2),
      ));
      expect(md, '# 标记\n\n> 创建于 2026-01-02');
    });

    test('无 note 时不残留多余空行', () {
      final md = BookmarkMarkdownExporter.exportSingle(_entry(
        id: 'bm4',
        label: '无备注',
        note: null,
        createdAt: DateTime(2026, 12, 31),
      ));
      // 标题后只应有一个空行再跟时间戳，不应有连续两个空行。
      expect(md, isNot(contains('\n\n\n')));
      expect(md.contains('# 无备注\n\n> 创建于 2026-12-31'), isTrue);
    });
  });

  group('BookmarkMarkdownExporter.exportAll', () {
    test('按创建时间升序 + --- 分隔', () {
      final md = BookmarkMarkdownExporter.exportAll([
        _entry(
            id: 'bm2',
            label: '后建的',
            note: 'b',
            createdAt: DateTime(2026, 7, 4)),
        _entry(
            id: 'bm1',
            label: '先建的',
            note: null,
            createdAt: DateTime(2026, 7, 1)),
      ]);
      // bm1 在前（创建更早），bm2 在后。
      expect(md.indexOf('先建的') < md.indexOf('后建的'), isTrue);
      expect(md, contains('---'));
      expect(md, contains('# 先建的\n\n> 创建于 2026-07-01'));
      expect(md, contains('# 后建的\n\nb\n\n> 创建于 2026-07-04'));
    });

    test('带 bookTitle 时顶部输出总标题', () {
      final md = BookmarkMarkdownExporter.exportAll(
        [
          _entry(
              id: 'bm1',
              label: '唯一',
              note: null,
              createdAt: DateTime(2026, 7, 1)),
        ],
        bookTitle: '深阅读',
      );
      expect(md.startsWith('# 《深阅读》书签'), isTrue);
      expect(md, contains('# 唯一'));
    });

    test('空列表只输出标题行（无 --- 无条目）', () {
      final md =
          BookmarkMarkdownExporter.exportAll([], bookTitle: '空书');
      expect(md.trim(), '# 《空书》书签');
    });

    test('空列表且无标题 → 空字符串', () {
      final md = BookmarkMarkdownExporter.exportAll([]);
      expect(md, '');
    });

    test('单条不输出 ---（分隔符仅在条目间）', () {
      final md = BookmarkMarkdownExporter.exportAll([
        _entry(
            id: 'bm1',
            label: '单条',
            note: null,
            createdAt: DateTime(2026, 7, 1)),
      ]);
      expect(md.contains('---'), isFalse);
    });
  });
}
