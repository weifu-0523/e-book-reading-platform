import 'package:meta/meta.dart';

import '../local/database.dart' as drift;

enum BookFormat { epub, pdf }

@immutable
class Book {
  final String id;
  final String title;
  final String? author;
  final BookFormat format;
  final String filePath;
  final String fileHash;
  final int fileSizeBytes;
  final String? coverPath;
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final int? sortOrder;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.filePath,
    required this.fileHash,
    required this.fileSizeBytes,
    required this.coverPath,
    required this.addedAt,
    required this.lastReadAt,
    this.sortOrder,
  });

  Book copyWith({
    String? title,
    String? author,
    String? coverPath,
    DateTime? lastReadAt,
    int? sortOrder,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format,
      filePath: filePath,
      fileHash: fileHash,
      fileSizeBytes: fileSizeBytes,
      coverPath: coverPath ?? this.coverPath,
      addedAt: addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Construct a [Book] from a drift-generated row. Centralizes the
  /// row -> domain model mapping so call sites don't each have to know the
  /// 11-field layout. The drift schema is the source of truth: if a column
  /// is added there, regenerating drift + adding it here updates every read
  /// site. Unknown format strings fall back to PDF defensively.
  factory Book.fromRow(drift.Book row) {
    return Book(
      id: row.id,
      title: row.title,
      author: row.author,
      format: row.format == 'epub' ? BookFormat.epub : BookFormat.pdf,
      filePath: row.filePath,
      fileHash: row.fileHash,
      fileSizeBytes: row.fileSizeBytes,
      coverPath: row.coverPath,
      addedAt: row.addedAt,
      lastReadAt: row.lastReadAt,
      sortOrder: row.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Book && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
