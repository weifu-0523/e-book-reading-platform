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

class TagEditor extends StatefulWidget {
  final List<String> tags;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  const TagEditor({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(String value) {
    final v = value.trim();
    if (v.isEmpty || widget.tags.contains(v)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.tags, v]);
    _controller.clear();
    _focus.requestFocus();
  }

  void _remove(String value) {
    widget.onChanged(widget.tags.where((t) => t != value).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...widget.tags.map((t) => Chip(
              label: Text(t),
              deleteIcon: const Icon(Icons.close),
              onDeleted: () => _remove(t),
            )),
        SizedBox(
          width: 120,
          child: Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              final v = textEditingValue.text;
              if (v.isEmpty) return const Iterable.empty();
              return widget.suggestions.where((s) => s.contains(v));
            },
            fieldViewBuilder: (ctx, controller, focus, onSubmitted) {
              return TextField(
                controller: _controller,
                focusNode: _focus,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '+ 添加',
                ),
                onSubmitted: _add,
              );
            },
            onSelected: _add,
          ),
        ),
      ],
    );
  }
}
