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

import 'package:meta/meta.dart';

/// 阅读引擎状态。
@immutable
sealed class ReaderEngineState {
  const ReaderEngineState();
}

class ReaderEngineUnloaded extends ReaderEngineState {
  const ReaderEngineUnloaded();
}

class ReaderEngineLoading extends ReaderEngineState {
  const ReaderEngineLoading();
}

class ReaderEngineReady extends ReaderEngineState {
  const ReaderEngineReady();
}

class ReaderEngineError extends ReaderEngineState {
  final String message;
  final Object? cause;

  const ReaderEngineError({required this.message, this.cause});
}
