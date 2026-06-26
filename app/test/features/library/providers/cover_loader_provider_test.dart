import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/providers/cover_loader_provider.dart';

import '../../../fakes/fake_book_repository.dart';

void main() {
  late FakeBookRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeBookRepository();
    container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWith((ref) => fakeRepo),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('coverLoaderProvider returns null when book not found', () async {
    final file = await container.read(coverLoaderProvider('missing').future);
    expect(file, isNull);
  });

  test('coverLoaderProvider returns null when book.coverPath is null', () async {
    await fakeRepo.save(_fakeBook('b1', coverPath: null));
    final file = await container.read(coverLoaderProvider('b1').future);
    expect(file, isNull);
  });

  test('coverLoaderProvider returns File when cover exists on disk', () async {
    // 写入真实临时文件
    final tempDir = await Directory.systemTemp.createTemp('cover_loader_test_');
    final coverFile = File('${tempDir.path}/cover.png')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    await fakeRepo.save(_fakeBook('b2', coverPath: coverFile.path));
    final file = await container.read(coverLoaderProvider('b2').future);
    expect(file, isNotNull);
    expect(file!.path, coverFile.path);
  });

  test('coverLoaderProvider returns null when coverPath file is missing on disk',
      () async {
    await fakeRepo.save(_fakeBook('b3', coverPath: '/nonexistent/cover.png'));
    final file = await container.read(coverLoaderProvider('b3').future);
    expect(file, isNull);
  });
}

Book _fakeBook(String id, {String? coverPath}) => Book(
      id: id,
      title: id,
      author: null,
      format: BookFormat.epub,
      filePath: '/$id.epub',
      fileHash: 'h-$id',
      fileSizeBytes: 100,
      coverPath: coverPath,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
