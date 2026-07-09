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

import 'dart:convert';

import '../../core/locator.dart';
import '../../services/sync/sync_recorder.dart';
import '../local/database.dart' as db;
import '../local/daos/annotations_dao.dart';
import '../local/daos/book_notes_dao.dart';
import '../models/annotation.dart';
import '../models/book_note.dart';
import 'notes_repository.dart';

class LocalNotesRepository implements NotesRepository {
  final BookNotesDao _notesDao;
  final AnnotationsDao _annotationsDao;
  final SyncRecorder? _syncRecorder;

  LocalNotesRepository(
    db.AppDatabase database, {
    SyncRecorder? syncRecorder,
  })  : _notesDao = BookNotesDao(database),
        _annotationsDao = AnnotationsDao(database),
        _syncRecorder = syncRecorder;

  @override
  Future<BookNote?> getNoteByBook(String bookId) async {
    final row = await _notesDao.getByBookId(bookId);
    if (row == null) return null;
    final annotations = await listAnnotations(row.id);
    return BookNote(
      id: row.id,
      bookId: row.bookId,
      title: row.title,
      summary: row.summary,
      keyTakeaways: _decodeStringList(row.keyTakeaways),
      annotations: annotations,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  }) async {
    final note = BookNote.empty(id: id, bookId: bookId, bookTitle: bookTitle);
    await _notesDao.insertOne(
      id: id,
      bookId: bookId,
      title: note.title,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );
    return note;
  }

  @override
  Future<void> updateNote(BookNote note) async {
    // 单次 now() 同时给 DB 和 sync recorder —— 避免 mtime μs 漂移导致
    // cross-device LWW 误判（参考 bookmark_repository.dart:83-96 同模式）。
    final now = DateTime.now();
    final keyTakeawaysJson = jsonEncode(note.keyTakeaways.toList());
    await _notesDao.updateContent(
      note.id,
      summary: note.summary,
      keyTakeawaysJson: keyTakeawaysJson,
      updatedAt: now,
    );
    await _syncRecorder?.recordBookNote(
      id: note.id,
      bookId: note.bookId,
      title: note.title,
      summary: note.summary,
      keyTakeawaysJson: keyTakeawaysJson,
      mtime: now,
    );
  }

  @override
  Future<List<Annotation>> listAnnotations(String noteId) async {
    final rows = await _annotationsDao.getByBookNoteId(noteId);
    return rows.map(_toAnnotationModel).toList();
  }

  @override
  Future<void> addAnnotation(Annotation a) async {
    await _annotationsDao.insertOne(
      id: a.id,
      bookNoteId: a.bookNoteId,
      locatorJson: jsonEncode(a.locator.toJson()),
      quote: a.quote,
      note: a.note,
      color: _colorToString(a.color),
      tagsJson: jsonEncode(a.tags.toList()),
      source: a.source == AnnotationSource.manual ? 'manual' : 'aiAssisted',
      createdAt: a.createdAt,
      updatedAt: a.updatedAt,
    );
    await _syncRecorder?.recordAnnotation(
      id: a.id,
      bookNoteId: a.bookNoteId,
      locatorJson: jsonEncode(a.locator.toJson()),
      quote: a.quote,
      note: a.note,
      color: _colorToString(a.color),
      tagsJson: jsonEncode(a.tags.toList()),
      source: a.source == AnnotationSource.manual ? 'manual' : 'aiAssisted',
      mtime: a.updatedAt,
    );
  }

  @override
  Future<void> updateAnnotation(Annotation a) async {
    // 用真正的 UPDATE，保留原 createdAt；单条 SQL 不需要事务。
    await _annotationsDao.updateAll(
      id: a.id,
      locatorJson: jsonEncode(a.locator.toJson()),
      quote: a.quote,
      note: a.note,
      color: _colorToString(a.color),
      tagsJson: jsonEncode(a.tags.toList()),
      source: a.source == AnnotationSource.manual ? 'manual' : 'aiAssisted',
      updatedAt: a.updatedAt,
    );
    await _syncRecorder?.recordAnnotation(
      id: a.id,
      bookNoteId: a.bookNoteId,
      locatorJson: jsonEncode(a.locator.toJson()),
      quote: a.quote,
      note: a.note,
      color: _colorToString(a.color),
      tagsJson: jsonEncode(a.tags.toList()),
      source: a.source == AnnotationSource.manual ? 'manual' : 'aiAssisted',
      mtime: a.updatedAt,
    );
  }

  @override
  Future<void> deleteAnnotation(String id) async {
    await _annotationsDao.deleteAnnotation(id);
    await _syncRecorder?.recordAnnotationDeletion(
      id: id,
      mtime: DateTime.now(),
    );
  }

  @override
  Future<List<Annotation>> searchAnnotations(
    String query, {
    List<String>? tags,
    HighlightColor? color,
  }) async {
    if (query.isEmpty && color == null && (tags == null || tags.isEmpty)) {
      return const <Annotation>[];
    }
    // 策略：query 非空时走 searchFts（子串 LIKE）；query 空但需要按 color/tags
    // 过滤时拉全表后内存过滤。数据规模（单用户笔记总数通常 < 1 万）允许这么做，
    // 避免在 DAO 拼接复杂 WHERE。
    final List<db.Annotation> rows;
    if (query.isNotEmpty) {
      rows = await _annotationsDao.searchFts(query);
    } else {
      rows = await _annotationsDao.getAll();
    }
    var models = rows.map(_toAnnotationModel).toList();
    if (color != null) {
      models = models.where((a) => a.color == color).toList();
    }
    if (tags != null && tags.isNotEmpty) {
      models = models.where((a) => tags.every(a.tags.contains)).toList();
    }
    return models;
  }

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) {
    // M4.6-fix10/A5: 修复首条摘录场景 stream 提前终结的 bug。
    //
    // 旧实现：`await getByBookId(bookId)` 是一次性 Future，noteRow == null 时
    // `yield []; return;` 终结 stream。但 BookNotes 表后续新增（_ensureBookNote）
    // 不会触发重发 → stream 已死 → 首条摘录后 UI 不刷新（要退出书架重进才看到）。
    //
    // 本实现：用 bookNotesDao.watchByBookId（drift .watch()，底层表变化重发）
    // 等待 BookNote 出现，出现后切换到 annotations watchByBookNoteId。
    // BookNote 已存在时：第一次 emit 立即切到 annotations watch（行为同旧实现）。
    // BookNote 不存在时：持续 emit []，直到 BookNote 被创建（首条摘录）后切换。
    //
    // 实现细节（2026-07-10 清理 T5）：改用 asyncExpand 而非 async* + await for。
    // 旧 async* 版本在 BookNote 不存在时一直阻塞在 await for 循环；当外部 cancel
    // 订阅时，drift 2.28 的内层 watch 订阅未被干净释放，残留 listener 让测试 isolate
    // 挂起 30s 超时（notes_repository_test 的 initial-empty case）。asyncExpand 由
    // stream 组合管理生命周期，cancel 外层会 cancel 内层，桌面/测试行为一致。
    return _notesDao.watchByBookId(bookId).asyncExpand((noteRow) {
      if (noteRow == null) {
        return Stream.value(const <Annotation>[]);
      }
      return _annotationsDao
          .watchByBookNoteId(noteRow.id)
          .map((rows) => rows.map(_toAnnotationModel).toList());
    });
  }

  @override
  Future<void> applyChapterReview({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String? chapterTitle,
    required String summary,
    required List<String> keyTakeaways,
  }) async {
    var note = await getNoteByBook(bookId);
    note ??= await createEmptyNote(
      id: 'note_$bookId',
      bookId: bookId,
      bookTitle: bookTitle,
    );

    final ordinal = chapterIndex + 1;
    final prefix = '【第$ordinal章】 ';
    final sentinelStart = '## 第 $ordinal 章';
    final sentinelTitle = (chapterTitle == null || chapterTitle.isEmpty)
        ? sentinelStart
        : '$sentinelStart · $chapterTitle';

    // --- keyTakeaways: 删旧加新 ---
    final existingTakeaways =
        note.keyTakeaways.where((t) => !t.startsWith(prefix)).toList();
    final newTakeaways = keyTakeaways.map((t) => '$prefix$t').toList();
    final mergedTakeaways = [...existingTakeaways, ...newTakeaways];

    // --- summary: 删旧加新 ---
    final cleanedSummary = _stripChapterSection(note.summary, sentinelStart);
    final newSection = StringBuffer()
      ..writeln(sentinelTitle)
      ..writeln()
      ..writeln(summary)
      ..writeln();
    final mergedSummary = cleanedSummary.isEmpty
        ? newSection.toString()
        : '${cleanedSummary.trimRight()}\n\n$newSection';

    await updateNote(note.copyWith(
      summary: mergedSummary,
      keyTakeaways: mergedTakeaways,
      updatedAt: DateTime.now(),
    ));
  }

  /// 删除 summary 中从 `## 第 N 章` 行起到下一个 `## ` 或字符串末尾的段落。
  String _stripChapterSection(String summary, String sentinelStart) {
    if (sentinelStart.isEmpty) return summary;
    if (!summary.contains(sentinelStart)) return summary;
    final sections = <String>[];
    final lines = summary.split('\n');
    var skipping = false;
    for (final line in lines) {
      if (line.startsWith('## ')) {
        skipping = line.startsWith(sentinelStart);
        if (!skipping) sections.add(line);
        continue;
      }
      if (!skipping) sections.add(line);
    }
    return sections.join('\n');
  }

  // ====== 私有 helpers ======

  Annotation _toAnnotationModel(db.Annotation row) {
    return Annotation(
      id: row.id,
      bookNoteId: row.bookNoteId,
      locator: Locator.fromJson(
        jsonDecode(row.locator) as Map<String, dynamic>,
      ),
      quote: row.quote,
      note: row.note,
      color: _colorFromString(row.color),
      tags: _decodeStringList(row.tags),
      source: row.source == 'aiAssisted'
          ? AnnotationSource.aiAssisted
          : AnnotationSource.manual,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String _colorToString(HighlightColor c) {
    switch (c) {
      case HighlightColor.yellow:
        return 'yellow';
      case HighlightColor.green:
        return 'green';
      case HighlightColor.blue:
        return 'blue';
      case HighlightColor.red:
        return 'red';
      case HighlightColor.purple:
        return 'purple';
    }
  }

  HighlightColor _colorFromString(String s) {
    return HighlightColor.values.firstWhere(
      (c) => _colorToString(c) == s,
      orElse: () => HighlightColor.yellow,
    );
  }

  List<String> _decodeStringList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    // 用 whereType<String> 而非 cast<String>：tags/keyTakeaways 由用户/AI 可控，
    // 外部写入（备份导入、同步、其他客户端 bug）可能含非 String 元素。
    // cast 是 lazy cast，会延迟到访问时抛；whereType 在解码时静默过滤。
    return list.whereType<String>().toList();
  }
}
