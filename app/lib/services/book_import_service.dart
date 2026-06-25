import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/local/file_storage.dart';
import '../data/models/book.dart';
import '../data/repositories/book_repository.dart';

class ImportResult {
  final Book book;
  final bool isNew;

  const ImportResult({required this.book, required this.isNew});
}

class BookImportService {
  final BookRepository _bookRepository;
  final FileStorage _fileStorage;
  final Uuid _uuid;

  BookImportService({
    required BookRepository bookRepository,
    required FileStorage fileStorage,
    Uuid? uuid,
  })  : _bookRepository = bookRepository,
        _fileStorage = fileStorage,
        _uuid = uuid ?? const Uuid();

  Future<ImportResult> importFile(
    File source, {
    required BookFormat format,
  }) async {
    final bytes = await source.readAsBytes();
    final hash = sha1.convert(bytes).toString();
    final extension = format == BookFormat.epub ? 'epub' : 'pdf';

    // Dedup by hash
    final existing = await _bookRepository.findByHash(hash);
    if (existing != null) {
      return ImportResult(book: existing, isNew: false);
    }

    // Store file
    final stored = await _fileStorage.storeLibraryFile(
      source: source,
      fileHash: hash,
      extension: extension,
    );

    // Create book record
    final fileName = p.basenameWithoutExtension(source.path);
    final book = Book(
      id: _uuid.v4(),
      title: fileName,
      author: null,
      format: format,
      filePath: stored.path,
      fileHash: hash,
      fileSizeBytes: bytes.length,
      coverPath: null,
      addedAt: DateTime.now(),
      lastReadAt: null,
    );
    await _bookRepository.save(book);

    return ImportResult(book: book, isNew: true);
  }
}
