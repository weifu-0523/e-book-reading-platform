import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Process-wide shared [http.Client]. Reused across AI services
/// ([OpenAiCompatibleClient], [AiGuide]) and the WebDAV sync client for
/// connection pooling. Override in tests with a mock client.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});
