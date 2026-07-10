// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';

/// 编辑 / 创建自由笔记。Bug #3 (2026-07-10)。
///
/// - [noteId] = null 且 [bookId] != null → 该书的新笔记
/// - [noteId] = null 且 [bookId] = null → 全局新笔记
/// - [noteId] != null → 编辑现有笔记（[bookId] 被忽略，从 DB 读现有 bookId）
///
/// 写穿（write-through）：每次 onChanged 启动 500ms debounce 后调 repo.update
/// （首次编辑调 create）。避免 exit(0) 截断 dispose Future —— 与
/// TypographyPersister 同模式（参见 feedback_no_dispose_time_fire_and_forget
/// memory）。
class NoteEditPage extends ConsumerStatefulWidget {
  const NoteEditPage({super.key, this.bookId, this.noteId});

  final String? bookId;
  final String? noteId;

  @override
  ConsumerState<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends ConsumerState<NoteEditPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _previewMode = false;
  bool _dirty = false;
  String? _createdId;
  bool _loadingExisting = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      _loadExisting();
    } else {
      _loadingExisting = false;
    }
  }

  Future<void> _loadExisting() async {
    final note =
        await ref.read(freeformNotesRepositoryProvider).get(widget.noteId!);
    if (note != null && mounted) {
      _titleCtrl.text = note.title;
      _contentCtrl.text = note.content;
    }
    if (mounted) setState(() => _loadingExisting = false);
  }

  void _onChanged() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    if (!_dirty) return;
    _dirty = false;
    final repo = ref.read(freeformNotesRepositoryProvider);
    final title =
        _titleCtrl.text.trim().isEmpty ? '无标题' : _titleCtrl.text.trim();
    final content = _contentCtrl.text;
    if (_createdId == null && widget.noteId == null) {
      _createdId = await repo.create(
        bookId: widget.bookId, title: title, content: content);
    } else {
      final id = _createdId ?? widget.noteId!;
      await repo.update(id: id, title: title, content: content);
    }
  }

  Future<void> _saveNow() async {
    _debounce?.cancel();
    if (_dirty) await _flush();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Best-effort synchronous flush; if exit(0) hits during dispose the
    // pending Future may be truncated, but the 500ms debounce means the
    // most recent edit already persisted. Mirrors TypographyPersister.
    if (_dirty) {
      Future.microtask(_flush);
    }
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleCtrl.text.isEmpty ? '新笔记' : _titleCtrl.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saveNow,
        ),
        actions: [
          IconButton(
            icon: Icon(_previewMode ? Icons.edit : Icons.visibility),
            onPressed: () => setState(() => _previewMode = !_previewMode),
            tooltip: _previewMode ? '编辑' : '预览',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveNow,
            tooltip: '保存',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _onChanged(),
            ),
          ),
          Expanded(
            child: _previewMode
                ? Markdown(
                    data: _contentCtrl.text,
                    padding: const EdgeInsets.all(12),
                    selectable: true,
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      minLines: 5,
                      decoration: const InputDecoration(
                        hintText: '支持 Markdown：# 标题、**加粗**、- 列表',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => _onChanged(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
