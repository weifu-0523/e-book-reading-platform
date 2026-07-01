import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/reading_progress_repository.dart';
import 'package:zhiyue/features/reader/services/progress_persister.dart';

class _FakeRepo implements ReadingProgressRepository {
  final List<ReadingProgress> saved = [];
  ReadingProgress? next;

  @override
  Future<ReadingProgress?> get(String bookId) async => next;

  @override
  Future<void> save(ReadingProgress progress) async {
    saved.add(progress);
    if (saved.length > 100) throw Exception('disk full (simulated)');
  }
}

void main() {
  test('rapid location changes persist once after 500ms idle', () async {
    final repo = _FakeRepo();
    final controller = StreamController<Locator>.broadcast();
    final persister = ProgressPersister(
      bookId: 'b1',
      repository: repo,
      source: controller.stream,
      debounceMs: 500,
    );
    // ignore: cascade_invocations - interleaving const, cannot cascade
    persister.start();

    const cfi1 = EpubCfiLocator(cfi: '/6/4', chapterIndex: 0);
    const cfi2 = EpubCfiLocator(cfi: '/6/8', chapterIndex: 0);
    controller
      ..add(cfi1)
      ..add(cfi2)
      ..add(cfi1);

    await Future.delayed(const Duration(milliseconds: 600));

    expect(repo.saved, hasLength(1));
    expect(repo.saved.first.bookId, 'b1');

    await controller.close();
    persister.dispose();
  });

  test('distinct CFIs do not double-write', () async {
    final repo = _FakeRepo();
    final controller = StreamController<Locator>.broadcast();
    final persister = ProgressPersister(
      bookId: 'b1',
      repository: repo,
      source: controller.stream,
      debounceMs: 100,
    );
    // ignore: cascade_invocations - interleaving const, cannot cascade
    persister.start();

    const cfi = EpubCfiLocator(cfi: '/6/4', chapterIndex: 0);
    controller.add(cfi);
    await Future.delayed(const Duration(milliseconds: 150));
    controller.add(cfi); // same value
    await Future.delayed(const Duration(milliseconds: 150));

    expect(repo.saved, hasLength(1));

    await controller.close();
    persister.dispose();
  });

  test('save failure is silent', () async {
    final repo = _FakeRepo();
    // ignore: cascade_invocations - property access only, cannot cascade
    repo.next = ReadingProgress(
      bookId: 'b1',
      locator: const EpubCfiLocator(cfi: '/6/4', chapterIndex: 0),
      percent: 0.0,
      updatedAt: DateTime.now(),
    );
    final controller = StreamController<Locator>.broadcast();
    final persister = ProgressPersister(
      bookId: 'b1',
      repository: repo,
      source: controller.stream,
      debounceMs: 50,
    );
    // ignore: cascade_invocations - interleaving for, cannot cascade
    persister.start();

    for (var i = 0; i < 200; i++) {
      controller.add(EpubCfiLocator(cfi: '/6/$i', chapterIndex: 0));
    }
    await Future.delayed(const Duration(milliseconds: 100));

    // 没有抛出
    expect(persister.isAlive, isTrue);

    await controller.close();
    persister.dispose();
  });
}
