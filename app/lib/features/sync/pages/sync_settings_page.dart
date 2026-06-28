import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../models/sync_status.dart';
import '../providers/sync_controller.dart';

class SyncSettingsPage extends ConsumerWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CredentialsSection(controller: controller),
          const SizedBox(height: 24),
          _StatusSection(state: state, l10n: l10n, controller: controller),
        ],
      ),
    );
  }
}

class _CredentialsSection extends StatefulWidget {
  const _CredentialsSection({required this.controller});
  final SyncController controller;

  @override
  State<_CredentialsSection> createState() => _CredentialsSectionState();
}

class _CredentialsSectionState extends State<_CredentialsSection> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.syncSectionData,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        TextField(
          controller: _userCtrl,
          decoration: InputDecoration(
            labelText: l10n.syncUsername,
            hintText: l10n.syncUsernameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.syncPassword,
            helperText: l10n.syncPasswordHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton(
              onPressed: () async {
                await widget.controller.saveCredentials(
                  username: _userCtrl.text,
                  password: _passCtrl.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.syncSaveCredentials)),
                  );
                }
              },
              child: Text(l10n.syncSaveCredentials),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () async {
                await widget.controller.clearCredentials();
                _userCtrl.clear();
                _passCtrl.clear();
              },
              child: Text(l10n.syncClearCredentials),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.state,
    required this.l10n,
    required this.controller,
  });
  final SyncState state;
  final AppLocalizations l10n;
  final SyncController controller;

  String _statusLabel(SyncStatus s) {
    switch (s) {
      case SyncStatus.idle:
        return l10n.syncStatusIdle;
      case SyncStatus.pushing:
        return l10n.syncStatusPushing;
      case SyncStatus.pulling:
        return l10n.syncStatusPulling;
      case SyncStatus.success:
        return l10n.syncStatusSuccess;
      case SyncStatus.error:
        return l10n.syncStatusError;
      case SyncStatus.offline:
        return l10n.syncStatusError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = state.status == SyncStatus.pushing ||
        state.status == SyncStatus.pulling;
    final lastRunText = state.lastSyncAt == null
        ? l10n.syncNever
        : '${l10n.syncLastRun}: ${state.lastSyncAt!.toLocal()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${l10n.syncStatusSuccess}: ${_statusLabel(state.status)}'),
        const SizedBox(height: 4),
        Text(lastRunText),
        if (state.lastMessage != null && state.status == SyncStatus.error)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(state.lastMessage!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isRunning ? null : () => controller.syncNow(),
          icon: isRunning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(l10n.syncNow),
        ),
      ],
    );
  }
}
