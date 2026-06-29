import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../models/sync_status.dart';
import '../providers/sync_controller.dart';
import '../widgets/conflict_list_tile.dart';
import '../widgets/interval_picker_dialog.dart';

class SyncStatusPage extends ConsumerStatefulWidget {
  const SyncStatusPage({super.key});

  @override
  ConsumerState<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends ConsumerState<SyncStatusPage> {
  Future<List<SyncConflict>>? _conflictsFuture;

  @override
  void initState() {
    super.initState();
    _reloadConflicts();
    // Pull conflict count into state for the AppBar actions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncControllerProvider.notifier).refreshConflictCount();
    });
  }

  void _reloadConflicts() {
    final controller = ref.read(syncControllerProvider.notifier);
    _conflictsFuture = controller.recentConflicts();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncStatusTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await controller.syncNow();
              setState(_reloadConflicts);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(state: state, l10n: l10n, controller: controller),
          const SizedBox(height: 16),
          _IntervalCard(state: state, l10n: l10n, controller: controller),
          const SizedBox(height: 16),
          _ConflictsCard(
            l10n: l10n,
            controller: controller,
            conflictsFuture: _conflictsFuture,
            onCleared: () => setState(_reloadConflicts),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
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
        return l10n.syncStatusOffline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = state.status == SyncStatus.pushing ||
        state.status == SyncStatus.pulling;
    final lastRunText = state.lastSyncAt == null
        ? l10n.syncNever
        : '${l10n.syncLastRun}: ${state.lastSyncAt!.toLocal()}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.syncStatusLabel}: ${_statusLabel(state.status)}'),
            const SizedBox(height: 4),
            Text(lastRunText),
            if (state.lastMessage != null && state.status == SyncStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.lastMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
        ),
      ),
    );
  }
}

class _IntervalCard extends StatelessWidget {
  const _IntervalCard({
    required this.state,
    required this.l10n,
    required this.controller,
  });
  final SyncState state;
  final AppLocalizations l10n;
  final SyncController controller;

  String _intervalLabel() {
    if (state.currentInterval == Duration.zero) return l10n.syncIntervalOff;
    return l10n.syncIntervalMinutes(state.currentInterval.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(l10n.syncIntervalTitle),
        subtitle: Text(_intervalLabel()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final picked = await showDialog<Duration>(
            context: context,
            builder: (_) => IntervalPickerDialog(
              current: state.currentInterval,
              onChanged: (d) {},
            ),
          );
          if (picked != null) {
            await controller.setInterval(picked);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.syncIntervalChanged)),
              );
            }
          }
        },
      ),
    );
  }
}

class _ConflictsCard extends StatelessWidget {
  const _ConflictsCard({
    required this.l10n,
    required this.controller,
    required this.conflictsFuture,
    required this.onCleared,
  });
  final AppLocalizations l10n;
  final SyncController controller;
  final Future<List<SyncConflict>>? conflictsFuture;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.syncConflictsSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () async {
                    await controller.clearConflicts();
                    onCleared();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.syncConflictsClearedOk)),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.syncConflictsClear),
                ),
              ],
            ),
            FutureBuilder<List<SyncConflict>>(
              future: conflictsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rows = snapshot.data!;
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.syncConflictsEmpty),
                  );
                }
                return Column(
                  children: rows
                      .map((r) => ConflictListTile(data: r))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
