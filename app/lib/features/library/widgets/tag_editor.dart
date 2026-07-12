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

/// Inline tag editor widget.
///
/// Displays existing tags as [InputChip]s with delete icons, plus an
/// [ActionChip] that expands a [TextField] for entering a new tag. Optional
/// [suggestions] are rendered as tappable [ActionChip]s below the existing
/// tags for quick-add.
///
/// Input validation:
/// - Rejects empty/whitespace-only after trim.
/// - Rejects `__` substring (reserved by sync composite key encoding
///   `${bookId}__${tag}` — collisions would break remote-record parsing).
/// - Rejects duplicates (case-insensitive).
/// - Truncates at [maxTagLength] via [TextField.maxLength] (default 32).
///
/// The widget is purely presentational: it owns only the "adding" input
/// state and emits a full replacement list via [onChanged]. The host is
/// responsible for persisting the new list (e.g. via `BookTagsRepository`).
class TagEditor extends StatefulWidget {
  const TagEditor({
    super.key,
    required this.tags,
    required this.onChanged,
    this.suggestions = const <String>{},
    this.maxTagLength = 32,
  });

  /// Current tag list. Order is preserved on add (new tag appended) and
  /// deletions keep remaining order stable.
  final List<String> tags;

  /// Optional suggestions rendered as quick-add chips. Suggestions already
  /// present in [tags] are filtered out to avoid duplicates.
  final Set<String> suggestions;

  /// Emitted with the full new tag list on every mutation (add via input,
  /// add via suggestion tap, delete via chip icon). The host applies the
  /// diff and persists as needed.
  final ValueChanged<List<String>> onChanged;

  /// Maximum tag length. The [TextField] uses [MaxLength] enforcement so
  /// the user cannot type past this limit. Defaults to 32.
  final int maxTagLength;

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  bool _isAdding = false;
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns an error message if [raw] fails any validation rule, else null.
  /// Rules are evaluated in order: empty → `__` → length → duplicate.
  /// The `__` check is critical for sync correctness: the composite key
  /// `${bookId}__${tag}` would be unparseable if the tag itself contains
  /// `__`, so we reject at the UI layer rather than throwing in the repo.
  String? _validate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '标签不能为空';
    if (trimmed.contains('__')) return '标签不能包含 "__"（同步键保留分隔符）';
    if (trimmed.length > widget.maxTagLength) {
      return '标签长度不能超过 ${widget.maxTagLength} 字符';
    }
    final lower = trimmed.toLowerCase();
    if (widget.tags.any((t) => t.toLowerCase() == lower)) {
      return '标签已存在';
    }
    return null;
  }

  void _commit() {
    final value = _controller.text;
    final error = _validate(value);
    if (error != null) {
      // Clear the offending input but keep the input expanded so the user
      // can retype. We surface the validation message via the
      // InputDecoration error slot; leaving the rejected text in the field
      // would make the displayed value indistinguishable from the error
      // (e.g. for the `__` separator rejection case both strings contain
      // `__`), so we wipe on error and let the user try again.
      setState(() {
        _errorText = error;
        _controller.clear();
      });
      return;
    }
    final newTags = [...widget.tags, value.trim()];
    widget.onChanged(newTags);
    setState(() {
      _isAdding = false;
      _controller.clear();
      _errorText = null;
    });
  }

  void _cancelAdd() {
    setState(() {
      _isAdding = false;
      _controller.clear();
      _errorText = null;
    });
  }

  void _addSuggestion(String tag) {
    // Defensive duplicate check (build() already filters suggestions whose
    // lowercase form matches an existing tag, but we re-check here in case
    // the host's `tags` and `suggestions` overlap when this handler fires).
    final lower = tag.toLowerCase();
    if (widget.tags.any((t) => t.toLowerCase() == lower)) return;
    widget.onChanged(<String>[...widget.tags, tag]);
  }

  @override
  Widget build(BuildContext context) {
    final existingLower = widget.tags.map((t) => t.toLowerCase()).toSet();
    final visibleSuggestions = widget.suggestions
        .where((s) => !existingLower.contains(s.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ...widget.tags.map((tag) {
              return InputChip(
                key: ValueKey('tag-editor-chip-$tag'),
                label: Text(tag),
                onDeleted: () {
                  widget.onChanged(
                    widget.tags.where((t) => t != tag).toList(),
                  );
                },
                // Keyed delete icon so widget tests can target the delete
                // affordance robustly. Each chip gets a unique key derived
                // from the tag — `first` in tests selects the first chip's
                // icon deterministically.
                deleteIcon: Icon(
                  Icons.cancel,
                  key: ValueKey('tag-editor-delete-icon-$tag'),
                  size: 18,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }),
            if (!_isAdding)
              ActionChip(
                key: const Key('tag-editor-add-btn'),
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('添加标签'),
                onPressed: () => setState(() {
                  _isAdding = true;
                  _errorText = null;
                }),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        if (visibleSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: visibleSuggestions.map((s) {
              return ActionChip(
                key: Key('tag-editor-suggestion-$s'),
                label: Text(s),
                avatar: const Icon(Icons.add, size: 14),
                onPressed: () => _addSuggestion(s),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
        if (_isAdding) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('tag-editor-input'),
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxTagLength,
            decoration: InputDecoration(
              isDense: true,
              hintText: '输入标签，回车确认',
              errorText: _errorText,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('tag-editor-confirm-btn'),
                    icon: const Icon(Icons.check, size: 20),
                    tooltip: '确认',
                    onPressed: _commit,
                  ),
                  IconButton(
                    key: const Key('tag-editor-cancel-btn'),
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: '取消',
                    onPressed: _cancelAdd,
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ],
      ],
    );
  }
}
