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
