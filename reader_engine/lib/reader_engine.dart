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

/// reader_engine — 阅读引擎抽象层。
library reader_engine;

export 'core/locator.dart';
export 'core/typography_settings.dart';
export 'core/book_ref.dart';
export 'rendering/pagination_model.dart';
export 'rendering/renderer.dart';
export 'rendering/highlight_range.dart';
export 'rendering/highlight_selection.dart';
export 'engine/reader_engine_state.dart';
export 'engine/reader_engine.dart';
export 'navigation/toc.dart';

const String readerEngineLibraryVersion = '0.1.0';
