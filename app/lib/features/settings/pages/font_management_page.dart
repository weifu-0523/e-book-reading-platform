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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/user_font.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../models/font_import_result.dart';
import '../providers/font_library_provider.dart';

/// 字体管理页面。
///
/// 上半部分列出系统字体（不可改）：Roboto / 系统默认。
/// 下半部分列出已导入的用户字体，每项支持重命名 / 删除。
/// 顶部按钮触发 [FontImportService] 导入流程。
///
/// 调用方约定：本页面不直接构造 FontImportService，而是 await
/// [fontImportServiceFutureProvider].future，避免在 build 期同步阻塞。
class FontManagementPage extends ConsumerWidget {
  const FontManagementPage({super.key});

  /// 系统字体只读列表（hardcode，UI 展示用）。
  /// 真正的渲染字体由 typography_profile.familyName 决定，
  /// 这里仅展示用户可挑选的内置项。
  static const List<String> systemFonts = <String>[
    'Roboto',
    'Serif',
    'Sans',
    'Monospace',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fontsAsync = ref.watch(fontLibraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fontManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.fontManagementImportButton,
            onPressed: () => _onImportTapped(context, ref),
          ),
        ],
      ),
      body: fontsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) {
          debugPrint('font_management_page load error: $e');
          return ErrorView(message: l10n.fontLoadFailed);
        },
        data: (fonts) => ListView(
          children: [
            // 系统字体（只读）
            _SectionHeader(label: l10n.fontManagementSystemFonts),
            for (final name in systemFonts)
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: Text(name),
                subtitle: Text(
                  name,
                  style: TextStyle(fontFamily: name, fontSize: 13),
                ),
              ),
            const Divider(),

            // 用户字体
            _SectionHeader(label: l10n.settingsCustomFonts),
            if (fonts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.fontManagementEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              for (final f in fonts)
                ListTile(
                  leading: const Icon(Icons.font_download),
                  title: Text(f.displayName),
                  subtitle: Text(
                    f.displayName,
                    style: TextStyle(fontFamily: f.familyName, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') {
                        _showRenameDialog(context, ref, f);
                      } else if (v == 'delete') {
                        _showDeleteConfirm(context, ref, f);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(l10n.fontManagementRename),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.fontManagementDelete),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _onImportTapped(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final service = await ref.read(fontImportServiceFutureProvider.future);
    final result = await service.importFont();
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case FontImportCancelled():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.fontManagementImportCancelled)),
        );
      case FontImportAlreadyExists(:final existing):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.fontManagementImportExists(existing.displayName),
            ),
          ),
        );
      case FontImportInvalid(:final reason):
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.fontManagementImportInvalid(reason)),
          ),
        );
      case FontImportReadError(:final message):
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.fontManagementImportReadError(message)),
          ),
        );
      case FontImportSuccess(:final font):
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.fontManagementImportSuccess(font.displayName)),
          ),
        );
        ref.invalidate(fontLibraryProvider);
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, UserFont f) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: f.displayName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fontManagementRename),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.fontManagementRenamePrompt),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.fontManagementCancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(userFontRepositoryProvider).rename(f.id, name);
              ref.invalidate(fontLibraryProvider);
            },
            child: Text(l10n.fontManagementConfirm),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, UserFont f) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fontManagementDeleteConfirmTitle),
        content: Text(l10n.fontManagementDeleteConfirmBody(f.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.fontManagementCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(userFontRepositoryProvider).delete(f.id);
              // 同步删除磁盘文件
              final file = File(f.absolutePath);
              if (await file.exists()) await file.delete();
              ref.invalidate(fontLibraryProvider);
            },
            child: Text(l10n.fontManagementDelete),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
