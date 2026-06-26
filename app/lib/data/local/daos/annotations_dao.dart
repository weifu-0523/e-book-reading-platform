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

  /// 反应式订阅：按 bookNoteId 观察该 note 的全部 annotation，
  /// 按 updatedAt 倒序（最近更新的在前）。
  Stream<List<Annotation>> watchByBookNoteId(String bookNoteId) {
    final query = select(annotations)
      ..where((t) => t.bookNoteId.equals(bookNoteId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
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
