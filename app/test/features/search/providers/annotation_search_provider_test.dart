import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/search/models/annotation_search_query.dart';
import 'package:zhiyue/features/search/providers/annotation_search_provider.dart';

import '../../../fakes/fake_notes_repository.dart';

void main() {
  test('search returns matches via repository', () async {
    final fake = FakeNotesRepository();
    await fake.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: '活着');
    await fake.addAnnotation(Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: const EpubRangeLocator(
          chapterIndex: 0, startOffset: 0, endOffset: 3, quote: '活着'),
      quote: '活着',
      note: null,
      color: HighlightColor.yellow,
      tags: const [],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));

    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    final future = container
        .read(annotationSearchProvider(
            const AnnotationSearchQuery(keyword: '活着'))
            .future);
    final results = await future;
    expect(results, hasLength(1));
    expect(results.first.id, 'a1');
  });

  test('empty keyword returns empty list without hitting repo', () async {
    final fake = FakeNotesRepository();
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    final results = await container.read(
        annotationSearchProvider(const AnnotationSearchQuery(keyword: '')).future);
    expect(results, isEmpty);
  });

  test('filters by tags when provided', () async {
    final fake = FakeNotesRepository();
    await fake.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    await fake.addAnnotation(Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: const EpubRangeLocator(
          chapterIndex: 0, startOffset: 0, endOffset: 3, quote: 'matching text'),
      quote: 'matching text',
      note: null,
      color: HighlightColor.yellow,
      tags: const ['哲学'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    await fake.addAnnotation(Annotation(
      id: 'a2',
      bookNoteId: 'bn1',
      locator: const EpubRangeLocator(
          chapterIndex: 0, startOffset: 0, endOffset: 3, quote: 'matching text'),
      quote: 'matching text',
      note: null,
      color: HighlightColor.yellow,
      tags: const ['小说'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));

    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    final results = await container.read(annotationSearchProvider(
        const AnnotationSearchQuery(keyword: 'matching', tags: ['哲学'])).future);
    expect(results.map((a) => a.id).toList(), ['a1']);
  });

  test('AnnotationSearchQuery equality supports provider caching', () {
    const q1 = AnnotationSearchQuery(keyword: 'abc', tags: ['x', 'y']);
    const q2 = AnnotationSearchQuery(keyword: 'abc', tags: ['y', 'x']);
    const q3 = AnnotationSearchQuery(keyword: 'abc', tags: ['x']);
    expect(q1 == q2, isTrue); // tags as set
    expect(q1 == q3, isFalse);
    expect(q1.hashCode, q2.hashCode);
  });
}
