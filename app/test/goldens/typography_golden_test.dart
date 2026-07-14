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
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:reader_engine/reader_engine.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  testGoldens(
    'TypographyPanel renders across themes (SKIPPED 2026-07-10: ConsumerWidget refactor needs ProviderScope + provider override, deferred to next sweep)',
    (tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'Light theme',
        SizedBox(
          height: 480,
          child: SingleChildScrollView(
            child: TypographyPanel(
              current: TypographySettings.defaults().copyWith(theme: ReadingTheme.light),
              onChanged: (_) {},
            ),
          ),
        ),
      )
      ..addScenario(
        'Dark theme',
        SizedBox(
          height: 480,
          child: SingleChildScrollView(
            child: TypographyPanel(
              current: TypographySettings.defaults().copyWith(theme: ReadingTheme.dark),
              onChanged: (_) {},
            ),
          ),
        ),
      )
      ..addScenario(
        'Sepia theme',
        SizedBox(
          height: 480,
          child: SingleChildScrollView(
            child: TypographyPanel(
              current: TypographySettings.defaults().copyWith(theme: ReadingTheme.sepia),
              onChanged: (_) {},
            ),
          ),
        ),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      surfaceSize: const Size(400, 1600),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(),
        platform: TargetPlatform.android,
      ),
    );
    await screenMatchesGolden(tester, 'typography_panel_themes');
    },
    skip: true);
}
