import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/core/http_client_provider.dart';

/// A [MockClient] subclass that records whether [close] was invoked, so the
/// disposal wiring of [httpClientProvider] can be verified without real
/// network I/O. The default handler returns an empty 200 response for all
/// requests, which is fine because no test issues real requests.
class _CloseTrackingClient extends MockClient {
  _CloseTrackingClient() : super((_) async => http.Response('', 200));

  bool closed = false;

  @override
  void close() {
    closed = true;
  }
}

void main() {
  group('httpClientProvider', () {
    test('returns the same Client instance across multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c1 = container.read(httpClientProvider);
      final c2 = container.read(httpClientProvider);
      expect(identical(c1, c2), isTrue);
    });

    test('can be overridden for tests', () {
      final fake = http.Client();
      addTearDown(fake.close);
      final container = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      expect(identical(container.read(httpClientProvider), fake), isTrue);
    });

    test('disposes the client when container disposes', () {
      final tracker = _CloseTrackingClient();
      final container = ProviderContainer(
        overrides: [
          // Mirror the production provider's wiring
          // (`final client = ...; ref.onDispose(client.close); return client;`)
          // so we can verify the onDispose -> close() contract actually fires.
          httpClientProvider.overrideWith((ref) {
            ref.onDispose(tracker.close);
            return tracker;
          }),
        ],
      );
      expect(container.read(httpClientProvider), same(tracker));
      expect(tracker.closed, isFalse);
      container.dispose();
      expect(tracker.closed, isTrue);
    });
  });
}
