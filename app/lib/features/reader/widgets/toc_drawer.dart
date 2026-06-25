import 'package:flutter/material.dart';
import 'package:reader_engine/navigation/toc.dart';

class TocDrawer extends StatelessWidget {
  final TableOfContents toc;
  final ValueChanged<TocEntry> onSelect;

  const TocDrawer({
    super.key,
    required this.toc,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (toc.entries.isEmpty) {
      return const Center(child: Text('本书无目录'));
    }
    return ListView.builder(
      itemCount: toc.entries.length,
      itemBuilder: (context, index) {
        final entry = toc.entries[index];
        return _TocTile(entry: entry, depth: 0, onSelect: onSelect);
      },
    );
  }
}

class _TocTile extends StatelessWidget {
  final TocEntry entry;
  final int depth;
  final ValueChanged<TocEntry> onSelect;

  const _TocTile({
    required this.entry,
    required this.depth,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 16.0, right: 16.0),
      title: InkWell(
        onTap: () => onSelect(entry),
        child: Text(entry.title),
      ),
      children: entry.children
          .map((child) => _TocTile(
                entry: child,
                depth: depth + 1,
                onSelect: onSelect,
              ))
          .toList(),
    );
  }
}
