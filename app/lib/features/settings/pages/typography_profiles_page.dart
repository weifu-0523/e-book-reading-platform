import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/typography_profile.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../widgets/profile_tile.dart';

class TypographyProfilesPage extends ConsumerWidget {
  const TypographyProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profilesAsync = ref.watch(typographyProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTypographyProfiles),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: profilesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) {
          debugPrint('typography_profiles_page load error: $e');
          return ErrorView(message: l10n.typographyProfilesLoadFailed);
        },
        data: (profiles) => profiles.isEmpty
            ? EmptyView(title: l10n.typographyProfilesEmpty)
            : ListView(
                children: profiles
                    .map((p) => ProfileTile(
                          profile: p,
                          isOnly: profiles.length == 1,
                          onSetDefault: () => ref
                              .read(typographyProfileRepositoryProvider)
                              .setDefault(p.id)
                              .then((_) => ref.invalidate(
                                  typographyProfileProvider)),
                          onRename: () => _showRenameDialog(context, ref, p),
                          onDelete: () => _showDeleteConfirm(context, ref, p),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: '新预设');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建预设'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final repo = ref.read(typographyProfileRepositoryProvider);
              await repo.insert(
                name: name,
                settings: (await repo.getDefault())!.settings,
                isDefault: false,
              );
              ref.invalidate(typographyProfileProvider);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, TypographyProfile p) {
    final ctrl = TextEditingController(text: p.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(typographyProfileRepositoryProvider).update(p.id, name: name);
              ref.invalidate(typographyProfileProvider);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, TypographyProfile p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定删除「${p.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(typographyProfileRepositoryProvider).delete(p.id);
              ref.invalidate(typographyProfileProvider);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
