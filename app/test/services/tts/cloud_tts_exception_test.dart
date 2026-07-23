import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';

void main() {
  group('CloudTtsException', () {
    test('carries kind + message + cause', () {
      final e = CloudTtsException(
        kind: CloudTtsErrorKind.network,
        message: 'SocketException: Connection refused',
        cause: 'original',
      );
      expect(e.kind, CloudTtsErrorKind.network);
      expect(e.message, 'SocketException: Connection refused');
      expect(e.cause, 'original');
    });

    test('fromHttpStatus maps common codes correctly', () {
      expect(CloudTtsErrorKind.fromHttpStatus(401), CloudTtsErrorKind.auth);
      expect(CloudTtsErrorKind.fromHttpStatus(403), CloudTtsErrorKind.auth);
      expect(CloudTtsErrorKind.fromHttpStatus(429), CloudTtsErrorKind.quota);
      expect(CloudTtsErrorKind.fromHttpStatus(500), CloudTtsErrorKind.server);
      expect(CloudTtsErrorKind.fromHttpStatus(503), CloudTtsErrorKind.server);
      expect(CloudTtsErrorKind.fromHttpStatus(400), CloudTtsErrorKind.invalidRequest);
      expect(CloudTtsErrorKind.fromHttpStatus(404), CloudTtsErrorKind.invalidRequest);
      expect(CloudTtsErrorKind.fromHttpStatus(200), CloudTtsErrorKind.invalidRequest); // unknown
    });

    test('isTransient returns true for network + server only', () {
      expect(CloudTtsErrorKind.network.isTransient, isTrue);
      expect(CloudTtsErrorKind.server.isTransient, isTrue);
      expect(CloudTtsErrorKind.auth.isTransient, isFalse);
      expect(CloudTtsErrorKind.quota.isTransient, isFalse);
      expect(CloudTtsErrorKind.invalidRequest.isTransient, isFalse);
    });
  });
}
