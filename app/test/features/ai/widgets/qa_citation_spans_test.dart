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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai/widgets/qa_citation_spans.dart';
import 'package:zhiyue/services/ai/qa_citation_parser.dart';

void main() {
  test('plain-only input produces one TextSpan with plain style', () {
    final spans = buildQaCitationSpans(
      [PlainSegment('Hello world.')],
      onCitationTap: (_) {},
      plainStyle: const TextStyle(color: Colors.black),
      citationStyle: const TextStyle(color: Colors.blue),
    );
    expect(spans, hasLength(1));
    final span = spans.first as TextSpan;
    expect(span.text, 'Hello world.');
    expect(span.recognizer, isNull);
  });

  test('CitationSegment produces TextSpan with TapGestureRecognizer', () {
    var tapped = -1;
    final spans = buildQaCitationSpans(
      [CitationSegment(7, '[ch=7]')],
      onCitationTap: (n) => tapped = n,
      plainStyle: const TextStyle(),
      citationStyle: const TextStyle(color: Colors.blue),
    );
    expect(spans, hasLength(1));
    final span = spans.first as TextSpan;
    expect(span.text, '[ch=7]');
    expect(span.recognizer, isA<TapGestureRecognizer>());
    (span.recognizer as TapGestureRecognizer).onTap?.call();
    expect(tapped, 7);
  });

  test('mixed segments produce ordered spans with correct recognizers', () {
    var tapped = <int>[];
    final spans = buildQaCitationSpans(
      [
        PlainSegment('Intro '),
        CitationSegment(1, '[ch=1]'),
        PlainSegment(' middle '),
        CitationSegment(5, '[ch=5]'),
      ],
      onCitationTap: tapped.add,
      plainStyle: const TextStyle(),
      citationStyle: const TextStyle(color: Colors.blue),
    );
    expect(spans, hasLength(4));
    expect((spans[0] as TextSpan).text, 'Intro ');
    expect((spans[0] as TextSpan).recognizer, isNull);
    expect((spans[1] as TextSpan).text, '[ch=1]');
    final rec1 = (spans[1] as TextSpan).recognizer as TapGestureRecognizer;
    rec1.onTap?.call();
    expect(tapped, [1]);
    final rec5 = (spans[3] as TextSpan).recognizer as TapGestureRecognizer;
    rec5.onTap?.call();
    expect(tapped, [1, 5]);
  });

  test('empty input produces empty list', () {
    expect(
        buildQaCitationSpans(
          const [],
          onCitationTap: (_) {},
          plainStyle: const TextStyle(),
          citationStyle: const TextStyle(),
        ),
        isEmpty);
  });
}
