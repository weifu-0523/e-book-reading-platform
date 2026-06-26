import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            hintText: '搜索高亮与笔记...',
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
    if (_query.isEmpty) {
      return const Center(child: Text('输入关键词搜索全部高亮'));
    }
    final async = ref.watch(
        annotationSearchProvider(AnnotationSearchQuery(keyword: _query)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('搜索失败：$e')),
      data: (results) {
        if (results.isEmpty) {
          return const Center(child: Text('无匹配结果'));
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (ctx, i) => AnnotationTile(
            annotation: results[i],
            chapterTitle: null,
          ),
        );
      },
    );
  }
}
