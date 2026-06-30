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
