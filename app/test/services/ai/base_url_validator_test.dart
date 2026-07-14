// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/base_url_validator.dart';

void main() {
  group('BaseUrlValidator', () {
    group('classify', () {
      test('https URL is safe', () {
        expect(
          BaseUrlValidator.classify('https://api.deepseek.com'),
          equals(BaseUrlSafety.safe),
        );
      });

      test('https URL with path is safe', () {
        expect(
          BaseUrlValidator.classify('https://api.openai.com/v1'),
          equals(BaseUrlSafety.safe),
        );
      });

      test('http localhost is safe (local dev)', () {
        expect(
          BaseUrlValidator.classify('http://localhost:8080'),
          equals(BaseUrlSafety.safe),
        );
      });

      test('http 127.0.0.1 is safe (loopback)', () {
        expect(
          BaseUrlValidator.classify('http://127.0.0.1:3000'),
          equals(BaseUrlSafety.safe),
        );
      });

      test('http 192.168.x.x is safe (LAN)', () {
        expect(
          BaseUrlValidator.classify('http://192.168.1.100:8080'),
          equals(BaseUrlSafety.safe),
        );
      });

      test('http 10.x.x.x is safe (LAN)', () {
        expect(
          BaseUrlValidator.classify('http://10.0.0.5:8080'),
          equals(BaseUrlSafety.safe),
        );
      });

      test('http 172.16.x.x is safe (LAN private range)', () {
        expect(
          BaseUrlValidator.classify('http://172.16.0.1:8080'),
          equals(BaseUrlSafety.safe),
        );
      });

      test('http public domain is unsafe (MITM risk)', () {
        expect(
          BaseUrlValidator.classify('http://api.deepseek.com'),
          equals(BaseUrlSafety.unsafeHttp),
        );
      });

      test('http public IP is unsafe', () {
        expect(
          BaseUrlValidator.classify('http://8.8.8.8'),
          equals(BaseUrlSafety.unsafeHttp),
        );
      });

      test('http 172.32.x.x is unsafe (outside private range)', () {
        // 172.16.0.0/12 is private; 172.32.x.x is public
        expect(
          BaseUrlValidator.classify('http://172.32.0.1'),
          equals(BaseUrlSafety.unsafeHttp),
        );
      });

      test('ftp URL is invalid scheme', () {
        expect(
          BaseUrlValidator.classify('ftp://example.com'),
          equals(BaseUrlSafety.invalidScheme),
        );
      });

      test('file URL is invalid scheme', () {
        expect(
          BaseUrlValidator.classify('file:///etc/passwd'),
          equals(BaseUrlSafety.invalidScheme),
        );
      });

      test('malformed URL is invalid', () {
        expect(
          BaseUrlValidator.classify('not a url'),
          equals(BaseUrlSafety.invalid),
        );
      });

      test('empty string is invalid', () {
        expect(
          BaseUrlValidator.classify(''),
          equals(BaseUrlSafety.invalid),
        );
      });

      test('URL without scheme is invalid', () {
        expect(
          BaseUrlValidator.classify('api.deepseek.com'),
          equals(BaseUrlSafety.invalid),
        );
      });
    });

    group('warningMessage', () {
      test('safe returns null', () {
        expect(
          BaseUrlValidator.warningMessage(BaseUrlSafety.safe),
          isNull,
        );
      });

      test('unsafeHttp returns non-null warning', () {
        expect(
          BaseUrlValidator.warningMessage(BaseUrlSafety.unsafeHttp),
          isNotNull,
        );
      });

      test('invalidScheme returns non-null warning', () {
        expect(
          BaseUrlValidator.warningMessage(BaseUrlSafety.invalidScheme),
          isNotNull,
        );
      });

      test('invalid returns non-null warning', () {
        expect(
          BaseUrlValidator.warningMessage(BaseUrlSafety.invalid),
          isNotNull,
        );
      });
    });
  });
}
