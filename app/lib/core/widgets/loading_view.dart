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

import '../../gen_l10n/app_localizations.dart';

/// A reusable loading indicator with an optional localized message.
///
/// Renders a centered column containing a [CircularProgressIndicator] of the
/// requested [size], followed by [message] (or [AppLocalizations.loadingDefaultMessage]
/// when null). Use it as the placeholder body while async data is in flight.
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.message,
    this.size = 32.0,
  });

  /// Optional override for the caption text. When null, the widget falls back
  /// to the localized default ([AppLocalizations.loadingDefaultMessage]).
  final String? message;

  /// Diameter of the [CircularProgressIndicator], in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caption = message ?? l10n.loadingDefaultMessage;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 16),
          Text(caption),
        ],
      ),
    );
  }
}
