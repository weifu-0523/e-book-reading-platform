import 'package:flutter/material.dart';
import '../../../data/models/annotation.dart';
import '../../../core/locator.dart';
import 'annotation_tile.dart';

class NotesDrawer extends StatelessWidget {
  final List<Annotation> annotations;
  final Map<int, String> chapterTitles;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;
  final VoidCallback onClose;

  const NotesDrawer({
    super.key,
    required this.annotations,
    required this.chapterTitles,
    required this.onTap,
    required this.onLongPress,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return Drawer(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Expanded(child: Center(child: Text('本书暂无高亮与笔记'))),
            ],
          ),
        ),
      );
    }
    final groups = <int, List<Annotation>>{};
    for (final a in annotations) {
      final locator = a.locator;
      if (locator is EpubRangeLocator) {
        groups.putIfAbsent(locator.chapterIndex, () => []).add(a);
      }
    }
    final sortedKeys = groups.keys.toList()..sort();
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: sortedKeys.length,
                itemBuilder: (ctx, i) {
                  final chapterIdx = sortedKeys[i];
                  final items = groups[chapterIdx]!
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(
                            chapterTitles[chapterIdx] ?? '第 ${chapterIdx + 1} 章',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                      ...items.map((a) => AnnotationTile(
                            annotation: a,
                            chapterTitle: null,
                            onTap: () => onTap(a.id),
                            onLongPress: () => onLongPress(a.id),
                          )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => ListTile(
        leading: const Icon(Icons.menu_book),
        title: const Text('本书高亮与笔记'),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      );
}
