import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/annotation.dart';
import '../models/annotation_search_query.dart';

final annotationSearchProvider = FutureProvider.autoDispose
    .family<List<Annotation>, AnnotationSearchQuery>((ref, query) async {
  if (query.keyword.isEmpty) return const [];
  final repo = ref.watch(notesRepositoryProvider);
  return repo.searchAnnotations(
    query.keyword,
    tags: query.tags.isEmpty ? null : query.tags,
    color: query.color,
  );
});
