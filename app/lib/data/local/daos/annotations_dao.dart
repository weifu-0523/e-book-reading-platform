import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/annotations.dart';

part 'annotations_dao.g.dart';

@DriftAccessor(tables: [Annotations])
class AnnotationsDao extends DatabaseAccessor<AppDatabase>
    with _$AnnotationsDaoMixin {
  AnnotationsDao(super.db);

  Future<List<Annotation>> getByBookNoteId(String bookNoteId) {
    return (select(annotations)..where((t) => t.bookNoteId.equals(bookNoteId)))
        .get();
  }

  /// 拉取全表 annotation。供 Repository 在用户已选定 color/tags 但无文本 query
  /// 时做内存过滤——单用户笔记规模通常 < 1 万，无需复杂 WHERE 拼接。
  Future<List<Annotation>> getAll() => select(annotations).get();

  /// 反应式订阅：按 bookNoteId 观察该 note 的全部 annotation，
  /// 按 updatedAt 倒序（最近更新的在前）。
  Stream<List<Annotation>> watchByBookNoteId(String bookNoteId) {
    final query = select(annotations)
      ..where((t) => t.bookNoteId.equals(bookNoteId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  /// 在 quote/note/tags 上做子串搜索，返回命中的全部 Annotation。
  ///
  /// 实现取子串 LIKE 而非 FTS5 MATCH：annotations_fts 虚表使用 FTS5 默认的
  /// unicode61 分词器，CJK 文本无词边界会被当作单个 token，导致「活着」这类
  /// 短中文查询无法命中「人是为了活着本身而活着」——对本应用以中文为主的高亮
  /// 文本，子串匹配才是用户预期。FTS5 表保留供未来按相关度排序/英文全文检索使用。
  Future<List<Annotation>> searchFts(String ftsQuery) async {
    if (ftsQuery.isEmpty) return const [];
    final pattern = '%$ftsQuery%';
    return (select(annotations)
          ..where((t) =>
              t.quote.like(pattern) |
              t.note.like(pattern) |
              t.tags.like(pattern)))
        .get();
  }

  Future<int> insertOne({
    required String id,
    required String bookNoteId,
    required String locatorJson,
    required String quote,
    String? note,
    required String color,
    required String tagsJson,
    required String source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return into(annotations).insert(
      AnnotationsCompanion.insert(
        id: id,
        bookNoteId: bookNoteId,
        locator: locatorJson,
        quote: quote,
        note: note == null ? const Value.absent() : Value(note),
        color: color,
        tags: Value(tagsJson),
        source: Value(source),
        createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
        updatedAt: updatedAt == null ? const Value.absent() : Value(updatedAt),
      ),
    );
  }

  Future<int> updateNote(String id, String? note) {
    return (update(annotations)..where((t) => t.id.equals(id))).write(
      AnnotationsCompanion(
        note: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 用真正的 UPDATE 更新所有可变字段，保留原 createdAt。
  Future<int> updateAll({
    required String id,
    required String locatorJson,
    required String quote,
    String? note,
    required String color,
    required String tagsJson,
    required String source,
    required DateTime updatedAt,
  }) {
    return (update(annotations)..where((t) => t.id.equals(id))).write(
      AnnotationsCompanion(
        locator: Value(locatorJson),
        quote: Value(quote),
        note: note == null ? const Value.absent() : Value(note),
        color: Value(color),
        tags: Value(tagsJson),
        source: Value(source),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<int> deleteAnnotation(String id) {
    return (delete(annotations)..where((t) => t.id.equals(id))).go();
  }
}
