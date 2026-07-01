import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/ai_summaries_dao.dart';

void main() {
  late AppDatabase db;
  late AiSummariesDao dao;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').get();
    await db.customStatement(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      "VALUES ('b1', 'Test', 'epub', '/p.epub', 'h1', 100)",
    );
    dao = db.aiSummariesDao;
  });

  tearDown(() async => db.close());

  test('insert then find by lookup key hits', () async {
    await dao.insert(
      bookId: 'b1',
      mode: 'full',
      sourceHash: 'sha-abc',
      summaryText: 'summary 1',
      modelName: 'deepseek-chat',
      baseUrl: 'https://api.deepseek.com',
      promptVersion: 1,
    );
    final hit = await dao.find(
      bookId: 'b1',
      mode: 'full',
      sourceHash: 'sha-abc',
      promptVersion: 1,
    );
    expect(hit, isNotNull);
    expect(hit!.summaryText, 'summary 1');
  });

  test('different prompt_version misses', () async {
    await dao.insert(
        bookId: 'b1',
        mode: 'full',
        sourceHash: 'sha',
        summaryText: 'v1',
        modelName: 'm',
        baseUrl: 'u',
        promptVersion: 1);
    expect(
        await dao.find(
            bookId: 'b1', mode: 'full', sourceHash: 'sha', promptVersion: 2),
        isNull);
  });

  test('different mode misses', () async {
    await dao.insert(
        bookId: 'b1',
        mode: 'full',
        sourceHash: 'sha',
        summaryText: 'a',
        modelName: 'm',
        baseUrl: 'u',
        promptVersion: 1);
    expect(
        await dao.find(
            bookId: 'b1', mode: 'chapter', sourceHash: 'sha', promptVersion: 1),
        isNull);
  });

  test('purgeForBook removes all rows for that book', () async {
    await dao.insert(
        bookId: 'b1',
        mode: 'full',
        sourceHash: 'h1',
        summaryText: 'a',
        modelName: 'm',
        baseUrl: 'u',
        promptVersion: 1);
    await dao.insert(
        bookId: 'b1',
        mode: 'chapter',
        sourceHash: 'h2',
        summaryText: 'b',
        modelName: 'm',
        baseUrl: 'u',
        promptVersion: 1);
    expect(await dao.purgeForBook('b1'), 2);
  });
}
