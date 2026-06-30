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

import 'token_truncator.dart';

/// One chunked passage produced by BookChunker (T4) and persisted by
/// BookPassagesDao.insertMany. Plain Dart class — no drift annotations.
class PassageChunk {
  const PassageChunk({
    required this.chapterIndex,
    required this.charOffset,
    required this.charLength,
    required this.contentText,
    required this.tokenEstimate,
  });

  final int chapterIndex;
  final int charOffset;
  final int charLength;
  final String contentText;
  final int tokenEstimate;
}

/// Pure-function chapter chunker used by BookPreprocessor (T5) Phase 1.
///
/// Strategy:
/// 1. Compute token estimate of the entire chapter via
///    TokenTruncator.estimateTokens.
/// 2. If <= chapterTokenLimit (100K): one chunk covers the whole text.
///    The chapter fits within LLM context windows comfortably; no slicing.
/// 3. If > 100K: split on \n\n boundaries, accumulating paragraphs into
///    slices of ~sliceTargetTokens (500). Final tail <100 tokens merges
///    into the previous slice to avoid tiny tail chunks.
///
/// Returns [] for empty / whitespace-only input.
class BookChunker {
  const BookChunker._();

  /// Chapter-level cutoff. Chapters above this token count get sliced.
  static const int chapterTokenLimit = 100000;

  /// Slice target size (tokens) when slicing is needed. Picked to fit
  /// comfortably within DeepSeek's context window after prompt overhead.
  static const int sliceTargetTokens = 500;

  /// Tail-merge threshold: a final slice smaller than this merges into the
  /// previous one. Avoids 1-paragraph stragglers.
  static const int _tailMergeThreshold = 100;

  /// Split [chapterText] into one or more PassageChunks for [chapterIndex].
  static List<PassageChunk> chunk(String chapterText, int chapterIndex) {
    if (chapterText.trim().isEmpty) return const [];

    final full = chapterText; // preserve original offsets
    final totalTokens = TokenTruncator.estimateTokens(full);
    if (totalTokens <= chapterTokenLimit) {
      return [
        PassageChunk(
          chapterIndex: chapterIndex,
          charOffset: 0,
          charLength: full.length,
          contentText: full,
          tokenEstimate: totalTokens,
        ),
      ];
    }

    // Long chapter: slice on \n\n boundaries.
    // Each paragraph carries its leading separator so absolute offsets
    // reconstruct the original text exactly when concatenated.
    final paragraphs = full.split('\n\n');
    final pieces = <String>[];
    for (var i = 0; i < paragraphs.length; i++) {
      pieces.add(i == 0 ? paragraphs[i] : '\n\n${paragraphs[i]}');
    }
    final slices = <_Slice>[];
    var current = _Slice();
    for (final piece in pieces) {
      final pieceTokens = TokenTruncator.estimateTokens(piece);
      if (current.tokens + pieceTokens > sliceTargetTokens && !current.isEmpty) {
        slices.add(current);
        current = _Slice()..append(piece, piece.length, pieceTokens);
      } else {
        current.append(piece, piece.length, pieceTokens);
      }
    }
    if (!current.isEmpty) slices.add(current);

    // Tail merge: if last slice is tiny, fold into previous.
    if (slices.length >= 2 && slices.last.tokens < _tailMergeThreshold) {
      final last = slices.removeLast();
      slices.last.absorb(last);
    }

    // Convert to PassageChunk with absolute offsets.
    final result = <PassageChunk>[];
    var offset = 0;
    for (final s in slices) {
      result.add(PassageChunk(
        chapterIndex: chapterIndex,
        charOffset: offset,
        charLength: s.length,
        contentText: s.text,
        tokenEstimate: s.tokens,
      ));
      offset += s.length;
    }
    return result;
  }
}

class _Slice {
  String text = '';
  int length = 0;
  int tokens = 0;

  bool get isEmpty => tokens == 0;

  void append(String piece, int charLength, int tokenDelta) {
    text += piece;
    length += charLength;
    tokens += tokenDelta;
  }

  void absorb(_Slice other) {
    text += other.text;
    length += other.length;
    tokens += other.tokens;
  }
}
