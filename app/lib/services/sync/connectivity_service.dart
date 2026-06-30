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

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around connectivity_plus for testability.
///
/// Strategy: connectivity_plus is used as a "fast offline hint" — if it
/// reports none, we skip the WebDAV round-trip. If it reports wifi/ethernet
/// but the network is actually down, the existing WebDavClient try/catch
/// still handles it. So this wrapper is non-blocking.
abstract class ConnectivityService {
  Future<bool> get isOnline;
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async {
    try {
      // connectivity_plus 6.x returns List<ConnectivityResult>.
      // Treat [none] (and only [none]) as offline.
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // connectivity_plus can throw on some Windows virtual NIC setups.
      // Fail-open: assume online; let WebDavClient try/catch catch real errors.
      return true;
    }
  }
}
