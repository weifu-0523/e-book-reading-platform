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

import 'package:flutter/material.dart';

import '../../ai/providers/book_preprocess_controller.dart';

/// Small status chip overlaid on a book cover while AI preprocessing runs.
/// Renders `AI ${currentChapter}/${totalChapters}` with a translucent
/// background so it reads on either cover or fallback color.
class PreprocessChip extends StatelessWidget {
  const PreprocessChip({super.key, required this.state});

  final PreprocessState state;

  @override
  Widget build(BuildContext context) {
    final label =
        'AI ${state.currentChapter}/${state.totalChapters > 0 ? state.totalChapters : '?'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

/// Amber "失败" chip shown when the preprocess run reached [PreprocessStatus.error].
class PreprocessFailedChip extends StatelessWidget {
  const PreprocessFailedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '失败',
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}
