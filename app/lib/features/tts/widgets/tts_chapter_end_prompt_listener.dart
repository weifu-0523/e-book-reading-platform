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

import '../../../gen_l10n/app_localizations.dart';
import '../providers/tts_reader_controller.dart';

/// Listens to [ttsChapterEndRequestProvider] and surfaces the corresponding
/// SnackBar via [ScaffoldMessenger] when the controller signals either:
///   * [TtsChapterEndKind.askContinue] — 「继续听下一章？」 with
///     继续 / 停止 actions.
///   * [TtsChapterEndKind.lastChapter] — 「已是最后一章」 with single dismiss.
///
/// Renders nothing (`SizedBox.shrink()`). Insert at the top of the reader
/// Stack so the inherited [ScaffoldMessenger] / [MaterialLocalizations]
/// resolve correctly. Mirrors the pattern used by [ReaderChapterEndPrompt]
/// for the regular 「本章已读完」 prompt (separate signal source).
///
/// Design rationale: [TtsReaderController] is a [StateNotifier] with no
/// [BuildContext]; instead of threading a global messenger key through
/// main.dart, we let the controller emit a request through a StateProvider
/// and let a small widget in the tree react.
class TtsChapterEndPromptListener extends ConsumerStatefulWidget {
  const TtsChapterEndPromptListener({super.key});

  @override
  ConsumerState<TtsChapterEndPromptListener> createState() =>
      _TtsChapterEndPromptListenerState();
}

class _TtsChapterEndPromptListenerState
    extends ConsumerState<TtsChapterEndPromptListener> {
  @override
  Widget build(BuildContext context) {
    ref.listen<TtsChapterEndRequest?>(
      ttsChapterEndRequestProvider,
      (prev, next) {
        if (next == null) return;
        _showSnackBar(context, next);
        // Reset the request once we've shown the SnackBar so subsequent
        // identical requests re-fire the listener.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(ttsChapterEndRequestProvider.notifier).state = null;
        });
      },
    );
    return const SizedBox.shrink();
  }

  void _showSnackBar(BuildContext context, TtsChapterEndRequest request) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    if (request.kind == TtsChapterEndKind.lastChapter) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.ttsChapterEndLastChapterMessage),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    // askContinue: inline content row with 继续 + 停止 buttons (SnackBar's
    // `action` slot only accepts one button).
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Expanded(
                child: Text(l10n.ttsChapterEndAskMessage),
              ),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  ref
                      .read(ttsReaderControllerProvider.notifier)
                      .continueToNextChapter();
                },
                child: Text(l10n.ttsChapterEndAskContinue),
              ),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  ref.read(ttsReaderControllerProvider.notifier).stop();
                },
                child: Text(l10n.ttsChapterEndAskStop),
              ),
            ],
          ),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
