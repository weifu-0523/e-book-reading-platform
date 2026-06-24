import 'package:meta/meta.dart';

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
  });

  Book copyWith({
    String? title,
    String? author,
    String? coverPath,
    DateTime? lastReadAt,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Book && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
