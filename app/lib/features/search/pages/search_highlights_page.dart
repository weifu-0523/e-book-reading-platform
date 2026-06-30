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
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../reader/widgets/annotation_tile.dart';
import '../models/annotation_search_query.dart';
import '../providers/annotation_search_provider.dart';

class SearchHighlightsPage extends ConsumerStatefulWidget {
  const SearchHighlightsPage({super.key});

  @override
  ConsumerState<SearchHighlightsPage> createState() =>
      _SearchHighlightsPageState();
}

class _SearchHighlightsPageState extends ConsumerState<SearchHighlightsPage> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onSubmitted: (v) => setState(() => _query = v.trim()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _query = _ctrl.text.trim()),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_query.isEmpty) {
      return EmptyView(
        title: l10n.searchEmptyKeywordHint,
        icon: Icons.search,
      );
    }
    final async = ref.watch(
        annotationSearchProvider(AnnotationSearchQuery(keyword: _query)));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: l10n.searchFailed),
      data: (results) {
        if (results.isEmpty) {
          return EmptyView(
            title: l10n.searchEmptyResultTitle,
            icon: Icons.search_off,
          );
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (ctx, i) => AnnotationTile(
            annotation: results[i],
            chapterTitle: null,
            onTap: () => context.push(
              '/book/${results[i].bookNoteId}',
              extra: results[i].locator,
            ),
          ),
        );
      },
    );
  }
}
