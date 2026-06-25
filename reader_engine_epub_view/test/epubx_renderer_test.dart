import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/rendering/renderer.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  test('EpubxRenderer implements EpubRenderer', () {
    final renderer = EpubxRenderer();
    expect(renderer, isA<EpubRenderer>());
  });

  test('initial state is unloaded', () {
    final renderer = EpubxRenderer();
    expect(renderer.state, const ReaderEngineUnloaded());
  });

  test('state\$ emits unloaded initially', () async {
    final renderer = EpubxRenderer();
    final first = await renderer.state$.first;
    expect(first, const ReaderEngineUnloaded());
  });

  test('openFile on non-existent path emits loading then error', () async {
    final renderer = EpubxRenderer();
    final states = <ReaderEngineState>[];
    final sub = renderer.state$.listen(states.add);

    await renderer.openFile('non/existent/path.epub');
    await Future.delayed(const Duration(milliseconds: 50));  // wait for stream emissions

    expect(states, contains(predicate<ReaderEngineState>(
      (s) => s is ReaderEngineLoading,
      'is ReaderEngineLoading',
    )));
    expect(states, contains(predicate<ReaderEngineState>(
      (s) => s is ReaderEngineError,
      'is ReaderEngineError',
    )));
    expect(renderer.state, isA<ReaderEngineError>());

    await sub.cancel();
    await renderer.dispose();
  });

  test('flatChapters is empty before openFile', () {
    final renderer = EpubxRenderer();
    expect(renderer.flatChapters, isEmpty);
  });

  test('gotoLocator with PdfPageLocator is a no-op (no throw)', () async {
    final renderer = EpubxRenderer();
    await renderer.gotoLocator(
      const PdfPageLocator(page: 1, offsetX: 0, offsetY: 0),
    );
    await renderer.dispose();
  });
}
