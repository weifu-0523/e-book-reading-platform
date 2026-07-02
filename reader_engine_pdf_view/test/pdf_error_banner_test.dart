// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_pdf_view/pdf_error_banner.dart';

void main() {
  group('PdfErrorBanner', () {
    testWidgets('renders friendly title + raw error detail', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfErrorBanner(
              error: Exception('No password supplied'),
            ),
          ),
        ),
      );

      expect(find.text('PDF 加载失败'), findsOneWidget);
      // Raw error still surfaced for diagnostics — but title is human-friendly.
      expect(find.textContaining('No password supplied'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows no retry button when callback omitted', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PdfErrorBanner(error: 'boom'),
          ),
        ),
      );

      expect(find.text('重试'), findsNothing);
    });

    testWidgets('invokes onRetry when button tapped', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfErrorBanner(
              error: 'boom',
              onRetry: () => retries++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('重试'));
      await tester.pump();

      expect(retries, 1);
    });
  });
}
