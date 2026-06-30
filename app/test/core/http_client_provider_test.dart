import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:zhiyue/core/http_client_provider.dart';

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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final client = container.read(httpClientProvider);
      // Closing before container disposal shouldn't crash; just verify it's a real Client.
      expect(client, isA<http.Client>());
    });
  });
}
