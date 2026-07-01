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

import '../../../gen_l10n/app_localizations.dart';

/// SnackBar shown by reader_body when [ChapterEndPromptController] state
/// becomes visible. Three inline [TextButton]s inside content row because
/// SnackBar's `action` slot accepts only one button.
///
/// Buttons:
/// - 回顾本章 / Review: always shown (detector only fires on EPUB path)
/// - 下一章 / Next: shown when [hasNext] is true (i.e., not last chapter)
/// - 关闭 / Dismiss: always shown
class ChapterEndPromptSnackBar extends SnackBar {
  ChapterEndPromptSnackBar({
    super.key,
    required BuildContext context,
    required bool hasNext,
    required VoidCallback onReview,
    required VoidCallback onNext,
    required VoidCallback onDismiss,
  }) : super(
          content: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.chapterEndPromptMessage,
                ),
              ),
              TextButton(
                onPressed: onReview,
                child: Text(
                  AppLocalizations.of(context)!.chapterEndPromptReview,
                ),
              ),
              if (hasNext)
                TextButton(
                  onPressed: onNext,
                  child: Text(
                    AppLocalizations.of(context)!.chapterEndPromptNext,
                  ),
                ),
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  AppLocalizations.of(context)!.chapterEndPromptDismiss,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 12),
          behavior: SnackBarBehavior.floating,
        );
}
