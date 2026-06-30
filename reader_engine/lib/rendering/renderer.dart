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

import '../core/locator.dart';
import '../core/typography_settings.dart';
import '../navigation/toc.dart';
import 'highlight_range.dart';
import 'highlight_selection.dart';
import 'pagination_model.dart';

/// EPUB 渲染器抽象 —— EPUB 类内部契约。
///
/// 实现类需包装具体的 EPUB 渲染库（如 epub_view_plus）。
/// UI 层永远不直接引用此接口，只看 [ReaderEngine]。
abstract interface class EpubRenderer {
  Widget build(BuildContext context);
  Future<void> openFile(String filePath);
  Stream<Locator> get currentLocation$;
  Future<TableOfContents> get toc;
  Future<void> gotoLocator(Locator locator);
  Future<void> setTypography(TypographySettings settings);
  Future<void> setPaginationMode(PaginationMode mode);
  Future<void> dispose();

  /// 推送当前书全部高亮区间，渲染时注入颜色 span。
  Future<void> injectHighlights(List<HighlightRange> highlights);

  /// 选区事件流。用户松开 selection 时 emit；非选区时段静默。
  Stream<HighlightSelection> get selection$;
}
