import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  test('nextSpine on empty book is a no-op (no throw)', () async {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    // No book loaded — flatChapters is empty
    await engine.nextSpine(); // should not throw
    await engine.previousSpine();
    await engine.close();
  });

  // Note: testing with a real book requires fixture EPUB;
  // integration tests in M2.5-5 will cover the happy path.
}
