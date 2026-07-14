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

import 'package:zhiyue/data/repositories/settings_repository.dart';

class FakeSettingsRepository implements SettingsRepository {
  final Map<String, dynamic> _map = {};

  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      _map[key] as T? ?? defaultValue;

  @override
  Future<T?> getOrNull<T>(String key) async => _map[key] as T?;

  @override
  Future<void> set<T>(String key, T value) async => _map[key] = value;

  /// Synchronous variant for test setup. Sets [key] to [value] in the
  /// in-memory map without awaiting — useful when seeding defaults before
  /// a widget is pumped (e.g. pinning a locale before [ZhiYueApp] boots).
  void setSync<T>(String key, T value) => _map[key] = value;
}
