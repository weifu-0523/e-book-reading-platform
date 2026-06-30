import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../services/ai/qa_citation_parser.dart';
import '../database.dart';
import '../tables/qa_history.dart';

part 'qa_history_dao.g.dart';

/// Subset of [QaHistoryDao] methods used outside the data layer (e.g. by
/// QaAskDialog). Declared as an interface so widgets can depend on the
/// capability without depending on drift internals, and tests can substitute
/// a trivial fake.
abstract class QaHistoryDaoLike {
  Future<List<QaHistoryEntry>> getByBook(String bookId, {int limit = 50});
  Future<QaHistoryEntry?> findSameQuestion(String bookId, String question);
  Future<String> insert({
    required String bookId,
    required String question,
    required String answer,
    required List<int> citations,
    DateTime? createdAt,
  });
  Future<int> deleteEntry(String id);
  Future<int> clearForBook(String bookId);
}

@DriftAccessor(tables: [QaHistory])
class QaHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$QaHistoryDaoMixin
    implements QaHistoryDaoLike {
  QaHistoryDao(super.db);

  /// Insert one Q&A entry. [citations] is encoded as JSON
  /// (e.g. "[3,5,8]"). Returns the inserted row's id.
  @override
  Future<String> insert({
    required String bookId,
    required String question,
    required String answer,
    required List<int> citations,
    DateTime? createdAt,
  }) async {
    final id = _generateId();
    await into(qaHistory).insert(
      QaHistoryCompanion.insert(
        id: id,
        bookId: bookId,
        question: question,
        answer: answer,
        citationsJson: jsonEncode(citations),
        createdAt:
            createdAt == null ? const Value.absent() : Value(createdAt),
      ),
    );
    return id;
  }

  /// Return entries for [bookId], newest first, capped at [limit].
  @override
  Future<List<QaHistoryEntry>> getByBook(String bookId,
      {int limit = 50}) async {
    final rows = await (select(qaHistory)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_toEntry).toList(growable: false);
  }

  /// Return the most recent entry whose question exactly matches, or null.
  /// Used by BookQaService to short-circuit a repeat ask without hitting
  /// the LLM. Exact-match only — fuzzy matching is YAGNI.
  @override
  Future<QaHistoryEntry?> findSameQuestion(
      String bookId, String question) async {
    final rows = await (select(qaHistory)
          ..where((t) => t.bookId.equals(bookId) & t.question.equals(question))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : _toEntry(rows.first);
  }

  /// Delete a single entry by id. Method named `deleteEntry` to avoid
  /// shadowing `DatabaseConnectionUser.delete<T>(TableInfo<T,D>)`.
  @override
  Future<int> deleteEntry(String id) {
    return (delete(qaHistory)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<int> clearForBook(String bookId) {
    return (delete(qaHistory)..where((t) => t.bookId.equals(bookId))).go();
  }

  QaHistoryEntry _toEntry(QaHistoryData row) {
    final decoded = jsonDecode(row.citationsJson);
    final citations = decoded is List
        ? decoded.map((e) => (e as num).toInt()).toList(growable: false)
        : const <int>[];
    return QaHistoryEntry(
      id: row.id,
      bookId: row.bookId,
      question: row.question,
      answer: row.answer,
      citations: citations,
      createdAt: row.createdAt,
    );
  }

  // Id generator: v4 UUID. Collision-proof under any realistic insertion
  // rate for single-user Q&A history.
  static const _uuid = Uuid();
  String _generateId() => _uuid.v4();
}
