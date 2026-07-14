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
import 'package:zhiyue/features/library/widgets/batch_selection_bar.dart';

void main() {
  testWidgets('renders selected count + delete/select-all buttons', (tester) async {
    var deleted = false;
    var selectedAll = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BatchSelectionBar(
          selectedCount: 3,
          onDelete: () => deleted = true,
          onSelectAll: () => selectedAll = true,
        ),
      ),
    ));
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.byIcon(Icons.select_all), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    expect(deleted, isTrue);

    await tester.tap(find.byIcon(Icons.select_all));
    expect(selectedAll, isTrue);
  });

  testWidgets('shows 0 count without crashing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BatchSelectionBar(
          selectedCount: 0,
          onDelete: () {},
          onSelectAll: () {},
        ),
      ),
    ));
    expect(find.textContaining('0'), findsOneWidget);
  });
}
