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
import 'package:zhiyue/features/sync/models/sync_status.dart';

/// Reusable sync CTA with state-aware visual + behavior.
///
/// - pushing/pulling: disabled + rotating sync icon (in-progress feedback)
/// - error: enabled for retry, error_outline icon, errorContainer color
/// - offline: disabled, cloud_off icon
/// - success: enabled, check icon (caller can revert to idle after a delay)
/// - idle: enabled, sync icon (default)
class SyncButton extends StatefulWidget {
  const SyncButton({
    super.key,
    required this.status,
    required this.label,
    required this.onPressed,
  });

  final SyncStatus status;
  final String label;
  final VoidCallback onPressed;

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant SyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    final isRunning = widget.status == SyncStatus.pushing ||
        widget.status == SyncStatus.pulling;
    if (isRunning) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isRunning =>
      widget.status == SyncStatus.pushing ||
      widget.status == SyncStatus.pulling;

  IconData get _icon {
    switch (widget.status) {
      case SyncStatus.pushing:
      case SyncStatus.pulling:
        return Icons.sync;
      case SyncStatus.error:
        return Icons.error_outline;
      case SyncStatus.offline:
        return Icons.cloud_off;
      case SyncStatus.success:
        return Icons.check;
      case SyncStatus.idle:
        return Icons.sync;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = widget.status == SyncStatus.error;

    Widget icon = Icon(_icon);
    if (_isRunning) {
      icon = RotationTransition(
        key: const ValueKey('sync_button_rotation'),
        turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
        child: icon,
      );
    }

    return FilledButton.icon(
      onPressed: _isRunning || widget.status == SyncStatus.offline
          ? null
          : widget.onPressed,
      style: isError
          ? FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            )
          : null,
      icon: icon,
      label: Text(widget.label),
    );
  }
}
