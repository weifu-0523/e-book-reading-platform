import 'package:zhiyue/features/library/providers/library_controller.dart';

/// In-memory fake [BookTagsLookup] for tests.
class FakeBookTagsLookup implements BookTagsLookup {
  final Set<String> _tags = {};

  void setTags(Set<String> tags) {
    _tags
      ..clear()
      ..addAll(tags);
  }

  @override
  Future<Set<String>> allTags() async => Set.unmodifiable(_tags);
}
