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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_session_controller.dart';

/// Top-row 2-card preset picker for the AI drawer.
///
/// Card 1 ("本章导读") triggers [ChatSessionController.runChapterGuide] with
/// `source: 'card.chapter'` — this is the same source string the AI message
/// list looks for to render the "本章导读" preset label (see [AiMessageList]).
///
/// Card 2 ("苏格拉底") triggers [ChatSessionController.runSocraticBootstrap],
/// which flips session mode to 'socratic' and streams the bootstrap question.
///
/// Both cards are disabled while [ChatSessionState.isStreaming] is true — the
/// LLM is mid-flight, no concurrent preset should be queued. Visual disabled
/// state is conveyed via 40% opacity (cards remain visible but greyed out).
///
/// `chapterIndex` is provided by the caller (reader's current chapter index).
/// When the value is unknown the caller may pass `0`; the use cases handle
/// out-of-range indices by surfacing a user-visible error in [ChatSessionState].
class AiPresetCardRow extends ConsumerWidget {
  const AiPresetCardRow({
    super.key,
    required this.bookId,
    required this.chapterIndex,
  });

  final String bookId;
  final int chapterIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatSessionControllerProvider(bookId));
    final enabled = !state.isStreaming;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _PresetCard(
              icon: Icons.menu_book,
              title: '本章导读',
              subtitle: '一键生成本章要点',
              enabled: enabled,
              onTap: () {
                ref
                    .read(chatSessionControllerProvider(bookId).notifier)
                    .runChapterGuide(
                      chapterIndex: chapterIndex,
                      source: 'card.chapter',
                    );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PresetCard(
              icon: Icons.psychology,
              title: '苏格拉底',
              subtitle: 'AI 主动提问引导',
              enabled: enabled,
              onTap: () {
                ref
                    .read(chatSessionControllerProvider(bookId).notifier)
                    .runSocraticBootstrap(chapterIndex: chapterIndex);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Card(
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: enabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
