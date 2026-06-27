import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_pdf_view/pdf_scanned_detector.dart';

void main() {
  group('PdfScannedDetector.isLikelyScannedByCharCount', () {
    test('totalChars < 100 returns true', () {
      expect(PdfScannedDetector.isLikelyScannedByCharCount(0), isTrue);
      expect(PdfScannedDetector.isLikelyScannedByCharCount(50), isTrue);
      expect(PdfScannedDetector.isLikelyScannedByCharCount(99), isTrue);
    });

    test('totalChars >= 100 returns false', () {
      expect(PdfScannedDetector.isLikelyScannedByCharCount(100), isFalse);
      expect(PdfScannedDetector.isLikelyScannedByCharCount(5000), isFalse);
    });
  });

  testWidgets('PdfScannedBanner renders warning text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PdfScannedBanner()),
    ));
    expect(find.textContaining('扫描件'), findsOneWidget);
  });

  testWidgets('PdfScannedBanner has warning icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PdfScannedBanner()),
    ));
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
  });
}
