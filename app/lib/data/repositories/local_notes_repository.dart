import 'dart:convert';

import '../../core/locator.dart';
import '../local/database.dart' as db;
import '../local/daos/annotations_dao.dart';
import '../local/daos/book_notes_dao.dart';
import '../models/annotation.dart';
import '../models/book_note.dart';
import 'notes_repository.dart';

class LocalNotesRepository implements NotesRepository {
  final BookNotesDao _notesDao;
  final AnnotationsDao _annotationsDao;

  LocalNotesRepository(db.AppDatabase database)
      : _notesDao = BookNotesDao(database),
        _annotationsDao = AnnotationsDao(database);

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
  Future<void> updateNote(BookNote note) {
    return _notesDao.updateContent(
      note.id,
      summary: note.summary,
      keyTakeawaysJson: jsonEncode(note.keyTakeaways.toList()),
    );
  }

  @override
  Future<List<Annotation>> listAnnotations(String noteId) async {
    final rows = await _annotationsDao.getByBookNoteId(noteId);
    return rows.map(_toAnnotationModel).toList();
  }

  @override
  Future<void> addAnnotation(Annotation a) {
    return _annotationsDao.insertOne(
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
  }

  @override
  Future<void> updateAnnotation(Annotation a) {
    // 用真正的 UPDATE，保留原 createdAt；单条 SQL 不需要事务。
    return _annotationsDao.updateAll(
      id: a.id,
      locatorJson: jsonEncode(a.locator.toJson()),
      quote: a.quote,
      note: a.note,
      color: _colorToString(a.color),
      tagsJson: jsonEncode(a.tags.toList()),
      source: a.source == AnnotationSource.manual ? 'manual' : 'aiAssisted',
      updatedAt: a.updatedAt,
    );
  }

  @override
  Future<void> deleteAnnotation(String id) =>
      _annotationsDao.deleteAnnotation(id);

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
  Stream<List<Annotation>> watchAnnotations(String bookId) async* {
    final noteRow = await _notesDao.getByBookId(bookId);
    if (noteRow == null) {
      yield const <Annotation>[];
      return;
    }
    yield* _annotationsDao
        .watchByBookNoteId(noteRow.id)
        .map((rows) => rows.map(_toAnnotationModel).toList());
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
