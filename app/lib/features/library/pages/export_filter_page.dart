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

import '../../../data/models/book.dart';
import '../../../data/models/book_note.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../notes/services/vault_exporter.dart';
import '../models/book_filter.dart';
import '../services/book_filter_applicator.dart';

/// 独立筛选页：用户配置 tag/addedAt/lastReadAt 三维度筛选后，
/// 通过 [onApply] 回调返回 [BookFilter]。
///
/// 预览列表只显示**会导出**的书（`applyBookFilter` + `VaultExporter.hasContent`
/// 双重过滤），保证预览数 == 实际导出数。
class ExportFilterPage extends StatefulWidget {
  const ExportFilterPage({
    super.key,
    required this.books,
    required this.notesByBookId,
    required this.tagsByBookId,
    required this.allTags,
    required this.now,
    required this.onApply,
  });

  final List<Book> books;
  final Map<String, BookNote> notesByBookId;
  final Map<String, Set<String>> tagsByBookId;
  final List<String> allTags;
  final DateTime now;
  final ValueChanged<BookFilter> onApply;

  @override
  State<ExportFilterPage> createState() => _ExportFilterPageState();
}

class _ExportFilterPageState extends State<ExportFilterPage> {
  final Set<String> _selectedTags = <String>{};
  TimeWindow _addedAtWindow = TimeWindow.any;
  TimeWindow _lastReadAtWindow = TimeWindow.any;

  BookFilter _currentFilter() => BookFilter(
        tags: Set<String>.from(_selectedTags),
        addedAtWindow: _addedAtWindow,
        lastReadAtWindow: _lastReadAtWindow,
      );

  List<Book> get _filteredBooks {
    final raw = applyBookFilter(
      books: widget.books,
      filter: _currentFilter(),
      tagsByBookId: widget.tagsByBookId,
      now: widget.now,
    );
    return raw.where((b) {
      final note = widget.notesByBookId[b.id];
      return note != null && VaultExporter.hasContent(note);
    }).toList();
  }

  void _reset() {
    setState(() {
      _selectedTags.clear();
      _addedAtWindow = TimeWindow.any;
      _lastReadAtWindow = TimeWindow.any;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filteredBooks;
    final totalHighlights = filtered.fold<int>(
      0,
      (sum, b) =>
          sum + (widget.notesByBookId[b.id]?.annotations.length ?? 0),
    );
    final isEmpty = filtered.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exportFilterTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.exportFilterResetTooltip,
            onPressed: _reset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (widget.allTags.isNotEmpty) _tagsSection(l10n),
          _addedAtSection(l10n),
          _lastReadAtSection(l10n),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.exportFilterPreviewSummary(filtered.length, totalHighlights),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final b in filtered) _bookTile(b),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: isEmpty ? null : () => widget.onApply(_currentFilter()),
            child: Text(
              isEmpty
                  ? l10n.exportFilterEmptyResult
                  : l10n.exportFilterActionExport(filtered.length),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tagsSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.exportFilterSectionTags,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: Text(l10n.exportFilterAllTagsChip),
                selected: _selectedTags.isEmpty,
                onSelected: (_) {
                  setState(_selectedTags.clear);
                },
              ),
              for (final tag in widget.allTags)
                FilterChip(
                  label: Text(tag),
                  selected: _selectedTags.contains(tag),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addedAtSection(AppLocalizations l10n) {
    return _radioSection<TimeWindow>(
      title: l10n.exportFilterSectionAddedAt,
      groupValue: _addedAtWindow,
      values: const [
        TimeWindow.any,
        TimeWindow.last7Days,
        TimeWindow.last30Days,
        TimeWindow.last90Days,
        TimeWindow.thisYear,
      ],
      label: _windowLabel,
      onChanged: (v) => setState(() => _addedAtWindow = v),
    );
  }

  Widget _lastReadAtSection(AppLocalizations l10n) {
    return _radioSection<TimeWindow>(
      title: l10n.exportFilterSectionLastReadAt,
      groupValue: _lastReadAtWindow,
      values: const [
        TimeWindow.any,
        TimeWindow.last7Days,
        TimeWindow.last30Days,
        TimeWindow.last90Days,
        TimeWindow.thisYear,
      ],
      label: _windowLabel,
      onChanged: (v) => setState(() => _lastReadAtWindow = v),
    );
  }

  String _windowLabel(TimeWindow w, AppLocalizations l10n) {
    switch (w) {
      case TimeWindow.any:
        return l10n.exportFilterTimeWindowAny;
      case TimeWindow.last7Days:
        return l10n.exportFilterTimeWindowLast7Days;
      case TimeWindow.last30Days:
        return l10n.exportFilterTimeWindowLast30Days;
      case TimeWindow.last90Days:
        return l10n.exportFilterTimeWindowLast90Days;
      case TimeWindow.thisYear:
        return l10n.exportFilterTimeWindowThisYear;
    }
  }

  Widget _radioSection<T>({
    required String title,
    required T groupValue,
    required List<T> values,
    required String Function(T, AppLocalizations) label,
    required ValueChanged<T> onChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          RadioGroup<T>(
            groupValue: groupValue,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final v in values)
                  RadioListTile<T>(
                    title: Text(label(v, l10n)),
                    value: v,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookTile(Book b) {
    final note = widget.notesByBookId[b.id]!;
    final highlights = note.annotations.length;
    final notes = note.annotations.where((a) => a.hasNote).length;
    final tags = widget.tagsByBookId[b.id] ?? const <String>{};
    return ListTile(
      leading: const Icon(Icons.book_outlined),
      title: Text(b.title),
      subtitle: Text(
        tags.isEmpty
            ? '$highlights · $notes'
            : '$highlights · $notes · ${tags.map((t) => '#$t').join(' ')}',
      ),
    );
  }
}
