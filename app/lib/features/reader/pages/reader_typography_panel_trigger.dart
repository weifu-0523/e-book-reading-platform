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
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:reader_engine/engine/reader_engine.dart';

import '../../../core/providers.dart';
import '../../../features/settings/providers/font_library_provider.dart';
import '../controllers/reader_ui_controller.dart';
import '../widgets/typography_panel.dart';

/// Extracted from reader_page.dart on T8 (2026-06-30).
///
/// 监听 [ReaderUiState.typographyPanelOpen] 并弹出/收起 [TypographyPanel] 的
/// 不可见 listener widget。
///
/// 抽成顶层 widget 让 reader_page.dart 只负责 page-level shell；本类负责
/// typography 面板的触发逻辑（不可见 listener → bottom sheet）。零行为变化
/// （原 `_TypographyPanelTrigger` 平移过来）。
class ReaderTypographyPanelTrigger extends ConsumerStatefulWidget {
  final ReaderEngine engine;

  const ReaderTypographyPanelTrigger({super.key, required this.engine});

  @override
  ConsumerState<ReaderTypographyPanelTrigger> createState() =>
      _ReaderTypographyPanelTriggerState();
}

class _ReaderTypographyPanelTriggerState
    extends ConsumerState<ReaderTypographyPanelTrigger> {
  bool _sheetShown = false;

  void _handleStateChange(bool open) {
    if (open && !_sheetShown) {
      _sheetShown = true;
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => Consumer(
          builder: (ctx, ref, _) {
            final profilesAsync = ref.watch(typographyProfileProvider);
            final fontsAsync = ref.watch(fontLibraryProvider);
            final profiles = profilesAsync.valueOrNull ?? const [];
            final userFonts = fontsAsync.valueOrNull ?? const [];
            final currentProfile = profiles.isEmpty
                ? null
                : profiles.firstWhere(
                    (p) => p.settings == widget.engine.typography,
                    orElse: () => profiles.first,
                  );
            return TypographyPanel(
              current: widget.engine.typography,
              onChanged: (settings) => widget.engine.setTypography(settings),
              profiles: profiles,
              currentProfile: currentProfile,
              onSelectProfile: (p) {
                widget.engine.setTypography(p.settings);
                ref.read(typographyProfileRepositoryProvider).setDefault(p.id);
              },
              onSaveAsProfile:
                  ({required settings, required overwrite, newName}) async {
                final repo =
                    ref.read(typographyProfileRepositoryProvider);
                if (overwrite) {
                  final def = await repo.getDefault();
                  if (def != null) {
                    await repo.update(def.id, settings: settings);
                  }
                } else {
                  await repo.insert(
                      name: newName ?? '新预设',
                      settings: settings,
                      isDefault: false);
                }
                ref.invalidate(typographyProfileProvider);
              },
              userFonts: userFonts,
            );
          },
        ),
      ).whenComplete(() {
        // 用户通过下滑或点击外部关闭 sheet 时，同步 UI 状态。
        _sheetShown = false;
        ref.read(readerUiControllerProvider.notifier).closeTypographyPanel();
      });
    } else if (!open && _sheetShown) {
      _sheetShown = false;
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(readerUiControllerProvider,
        (previous, next) => _handleStateChange(next.typographyPanelOpen));
    return const SizedBox.shrink();
  }
}
