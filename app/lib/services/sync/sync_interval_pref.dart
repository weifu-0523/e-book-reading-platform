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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Test-facing interface. SyncIntervalPref implements this implicitly.
abstract class SyncIntervalPrefLike {
  Future<Duration> load();
  Future<void> save(Duration interval);
  Future<void> clear();
}

/// Persisted background-sync interval (Duration).
///
/// Stored under `zhiyue.sync.intervalMinutes` as integer minutes.
/// Duration.zero means "off" (manual sync only). Default on first load
/// is 5 minutes.
class SyncIntervalPref implements SyncIntervalPrefLike {
  SyncIntervalPref([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'zhiyue.sync.intervalMinutes';
  static const _defaultMinutes = 5;

  final FlutterSecureStorage _storage;

  @override
  Future<Duration> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return const Duration(minutes: _defaultMinutes);
    final minutes = int.tryParse(raw);
    if (minutes == null || minutes < 0) {
      return const Duration(minutes: _defaultMinutes);
    }
    return Duration(minutes: minutes);
  }

  @override
  Future<void> save(Duration interval) async {
    final minutes = interval.inMinutes;
    await _storage.write(key: _key, value: minutes.toString());
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
