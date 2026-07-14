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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

/// 接口可被实现的 smoke test。
class _FakeEngine implements ReaderEngine {
  @override
  ReaderEngineState state = const ReaderEngineUnloaded();

  @override
  Stream<ReaderEngineState> get state$ => const Stream.empty();

  @override
  Stream<Locator> get currentLocation$ => const Stream.empty();

  @override
  Future<String> get currentChapterPlainText => Future.value('');

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  TableOfContents? get toc => null;

  @override
  TypographySettings get typography => TypographySettings.defaults();

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  bool get dualPageMode => false;

  @override
  int get currentSpreadCount => 0;

  @override
  int get currentSpreadIndex => 0;

  @override
  Future<void> open(BookRef book) async {}
  @override
  Future<void> gotoLocator(Locator locator) async {}
  @override
  Future<void> gotoTocEntry(TocEntry entry) async {}
  @override
  Future<void> nextSpine() async {}
  @override
  Future<void> previousSpine() async {}
  @override
  bool nextPage() => false;
  @override
  bool previousPage() => false;
  @override
  Future<void> setTypography(TypographySettings settings) async {}
  @override
  Future<void> setPaginationMode(PaginationMode mode) async {}
  @override
  void scrollBy(double delta, {Duration duration = const Duration(milliseconds: 200)}) {}
  @override
  Future<void> close() async {}
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

void main() {
  test('ReaderEngine can be implemented', () {
    final engine = _FakeEngine();
    expect(engine.state, isA<ReaderEngineUnloaded>());
    expect(engine.paginationMode, PaginationMode.paged);
  });
}
