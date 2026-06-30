import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/book.dart';
import '../../../data/models/book_note.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../notes/services/vault_exporter.dart';

/// Modal dialog that drives [VaultExporter.export] while showing live progress
/// and a cancel affordance.
///
/// On completion (success, cancel, or unexpected error) the [onCompleted]
/// callback is invoked exactly once with the best-effort [VaultExportResult]:
/// - success: the exporter's real result.
/// - cancel: a partial result built from the last reported `_current`
///   (clamped to >= 0); the exporter loop halts because the next
///   [onProgress] callback throws [_CancelledException].
/// - error: an empty result with zero counts.
///
/// The dialog itself does not pop — the host is responsible for dismissing it
/// once [onCompleted] runs (e.g. via `Navigator.pop` + a follow-up SnackBar).
class BatchExportDialog extends StatefulWidget {
  const BatchExportDialog({
    super.key,
    required this.targetDirPath,
    required this.books,
    required this.notesByBookId,
    required this.onCompleted,
  });

  final String targetDirPath;
  final List<Book> books;
  final Map<String, BookNote> notesByBookId;
  final ValueChanged<VaultExportResult> onCompleted;

  @override
  State<BatchExportDialog> createState() => _BatchExportDialogState();
}

class _BatchExportDialogState extends State<BatchExportDialog> {
  int _current = 0;
  int _total = 0;
  String _currentTitle = '';
  bool _cancelled = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _total = widget.books.length;
    // Schedule after first frame so the dialog paints before export starts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runExport());
  }

  Future<void> _runExport() async {
    try {
      final result = await VaultExporter.export(
        books: widget.books,
        notesByBookId: widget.notesByBookId,
        targetDir: Directory(widget.targetDirPath),
        now: DateTime.now(),
        onProgress: (current, total, title) {
          if (_cancelled) throw const _CancelledException();
          if (!mounted) return;
          setState(() {
            _current = current;
            _total = total;
            _currentTitle = title;
          });
        },
      );
      if (mounted && !_completed) {
        _completed = true;
        widget.onCompleted(result);
      }
    } on _CancelledException {
      if (mounted && !_completed) {
        _completed = true;
        final exportedSoFar = _current - 1 < 0 ? 0 : _current - 1;
        widget.onCompleted(VaultExportResult(
          booksExported: exportedSoFar,
          totalHighlights: 0,
          totalNotes: 0,
          writtenFiles: const [],
          failures: const [],
        ));
      }
    } catch (_) {
      if (mounted && !_completed) {
        _completed = true;
        widget.onCompleted(const VaultExportResult(
          booksExported: 0,
          totalHighlights: 0,
          totalNotes: 0,
          writtenFiles: [],
          failures: [],
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.batchExportConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _total == 0 ? null : _current / _total,
          ),
          const SizedBox(height: 12),
          Text(l10n.batchExportProgress(_current, _total, _currentTitle)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _completed ? null : () => setState(() => _cancelled = true),
          child: Text(l10n.reviewCancelButton),
        ),
      ],
    );
  }
}

class _CancelledException implements Exception {
  const _CancelledException();
}
