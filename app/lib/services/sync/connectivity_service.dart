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
