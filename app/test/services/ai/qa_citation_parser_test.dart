import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/qa_citation_parser.dart';

void main() {
  group('QaCitationParser.parse', () {
    test('plain text with no markers yields one PlainSegment', () {
      final segs = QaCitationParser.parse('Hello world.');
      expect(segs, hasLength(1));
      expect(segs.first, isA<PlainSegment>());
      expect((segs.first as PlainSegment).text, 'Hello world.');
    });

    test('single [ch=N] marker yields PlainSegment + CitationSegment', () {
      final segs = QaCitationParser.parse('See chapter [ch=3] for details.');
      expect(segs, hasLength(3));
      expect((segs[0] as PlainSegment).text, 'See chapter ');
      expect((segs[1] as CitationSegment).chapterIndex, 3);
      expect((segs[1] as CitationSegment).marker, '[ch=3]');
      expect((segs[2] as PlainSegment).text, ' for details.');
    });

    test('multiple markers in sequence parse correctly', () {
      final segs = QaCitationParser.parse('[ch=0] then [ch=5] then [ch=10]');
      final citations = segs.whereType<CitationSegment>().toList();
      expect(citations.map((c) => c.chapterIndex).toList(), [0, 5, 10]);
    });

    test('markers preserve order with surrounding text', () {
      final segs = QaCitationParser.parse('Intro [ch=1] middle [ch=2] end');
      expect((segs[0] as PlainSegment).text, 'Intro ');
      expect((segs[1] as CitationSegment).chapterIndex, 1);
      expect((segs[2] as PlainSegment).text, ' middle ');
      expect((segs[3] as CitationSegment).chapterIndex, 2);
      expect((segs[4] as PlainSegment).text, ' end');
    });

    test('invalid marker [ch=abc] is treated as plain text', () {
      final segs = QaCitationParser.parse('Bad [ch=abc] marker');
      expect(segs.whereType<CitationSegment>(), isEmpty);
      final joined = segs
          .map((s) => s is PlainSegment ? s.text : (s as CitationSegment).marker)
          .join();
      expect(joined, 'Bad [ch=abc] marker');
    });

    test('consecutive markers with no text between yield two citations', () {
      final segs = QaCitationParser.parse('[ch=1][ch=2]');
      final citations = segs.whereType<CitationSegment>().toList();
      expect(citations, hasLength(2));
      expect(citations[0].chapterIndex, 1);
      expect(citations[1].chapterIndex, 2);
    });

    test('empty input yields empty list', () {
      expect(QaCitationParser.parse(''), isEmpty);
    });
  });

  group('QaCitationParser.extractCitations', () {
    test('returns chapter indices in order, deduped', () {
      final cites = QaCitationParser.extractCitations('a [ch=3] b [ch=3] c [ch=7]');
      expect(cites, [3, 7]);
    });

    test('returns empty list when no markers', () {
      expect(QaCitationParser.extractCitations('no markers here'), isEmpty);
    });
  });
}
