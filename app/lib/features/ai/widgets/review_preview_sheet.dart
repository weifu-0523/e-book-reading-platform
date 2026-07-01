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

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../services/ai/book_reviewer.dart';
import '../providers/review_controller.dart';

/// Modal bottom sheet that previews an AI-generated chapter review.
///
/// State is read from [reviewControllerProvider]. The caller is responsible
/// for invoking `controller.start(...)` before showing this sheet.
///
/// [onSaved] is invoked after the user taps "save" — the caller does the
/// actual persistence (calling `applyChapterReview` on the notes repo).
/// The sheet awaits [onSaved] before popping so the modal doesn't dismiss
/// mid-write (which would race with `applyChapterReview`'s DB insert).
class ReviewPreviewSheet extends ConsumerWidget {
  const ReviewPreviewSheet({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.onSaved,
  });

  final String bookId;
  final int chapterIndex;
  final String? chapterTitle;
  final Future<void> Function()? onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(reviewControllerProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewSheetTitle(
            chapterIndex + 1,
            chapterTitle ?? l10n.reviewEmptyHighlightsHint)),
      ),
      body: _body(context, ref, l10n, state),
      bottomNavigationBar: _bottomBar(context, ref, l10n, state),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ReviewState state,
  ) {
    switch (state.status) {
      case ReviewStatus.idle:
      case ReviewStatus.loading:
        return LoadingView(message: l10n.reviewStatusLoading);
      case ReviewStatus.streaming:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.reviewStatusStreaming,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Text(state.rawText),
          ],
        );
      case ReviewStatus.done:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.reviewSummarySection,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(state.summary ?? ''),
            const SizedBox(height: 24),
            Text(l10n.reviewTakeawaysSection,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final t in state.keyTakeaways) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(t)),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ],
        );
      case ReviewStatus.error:
        return ErrorView(
          message: _errorMessage(l10n, state.error),
          onRetry: () => ref
              .read(reviewControllerProvider(bookId).notifier)
              .reset(),
        );
    }
  }

  Widget _bottomBar(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ReviewState state,
  ) {
    if (state.status == ReviewStatus.error) {
      return SafeArea(
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.reviewCancelButton),
            ),
          ],
        ),
      );
    }
    final canSave = state.status == ReviewStatus.done;
    return SafeArea(
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.reviewCancelButton),
          ),
          FilledButton(
            onPressed: canSave
                ? () async {
                    await onSaved?.call();
                    if (context.mounted) Navigator.of(context).maybePop();
                  }
                : null,
            child: Text(l10n.reviewSaveButton),
          ),
        ],
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n, ReviewError? error) {
    switch (error) {
      case ReviewError.authFailed:
        return l10n.reviewErrorAuthFailed;
      case ReviewError.parseError:
        return l10n.reviewErrorParseFailed;
      case ReviewError.serverError:
      case ReviewError.rateLimited:
      case null:
        return l10n.reviewErrorServer;
    }
  }
}
