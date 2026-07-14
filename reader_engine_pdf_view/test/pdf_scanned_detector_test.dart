// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
