// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    format,
    filePath,
    fileHash,
    fileSizeBytes,
    coverPath,
    addedAt,
    lastReadAt,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    } else if (isInserting) {
      context.missing(_fileHashMeta);
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fileSizeBytesMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      )!,
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final String id;
  final String title;
  final String? author;
  final String format;
  final String filePath;
  final String fileHash;
  final int fileSizeBytes;
  final String? coverPath;
  final DateTime addedAt;
  final DateTime? lastReadAt;

  /// M3.1：手动排序顺序；null = 不参与手动排序，按默认排序。
  final int? sortOrder;
  const Book({
    required this.id,
    required this.title,
    this.author,
    required this.format,
    required this.filePath,
    required this.fileHash,
    required this.fileSizeBytes,
    this.coverPath,
    required this.addedAt,
    this.lastReadAt,
    this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['format'] = Variable<String>(format);
    map['file_path'] = Variable<String>(filePath);
    map['file_hash'] = Variable<String>(fileHash);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      format: Value(format),
      filePath: Value(filePath),
      fileHash: Value(fileHash),
      fileSizeBytes: Value(fileSizeBytes),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      addedAt: Value(addedAt),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      format: serializer.fromJson<String>(json['format']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileHash: serializer.fromJson<String>(json['fileHash']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastReadAt: serializer.fromJson<DateTime?>(json['lastReadAt']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'format': serializer.toJson<String>(format),
      'filePath': serializer.toJson<String>(filePath),
      'fileHash': serializer.toJson<String>(fileHash),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'coverPath': serializer.toJson<String?>(coverPath),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastReadAt': serializer.toJson<DateTime?>(lastReadAt),
      'sortOrder': serializer.toJson<int?>(sortOrder),
    };
  }

  Book copyWith({
    String? id,
    String? title,
    Value<String?> author = const Value.absent(),
    String? format,
    String? filePath,
    String? fileHash,
    int? fileSizeBytes,
    Value<String?> coverPath = const Value.absent(),
    DateTime? addedAt,
    Value<DateTime?> lastReadAt = const Value.absent(),
    Value<int?> sortOrder = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    format: format ?? this.format,
    filePath: filePath ?? this.filePath,
    fileHash: fileHash ?? this.fileHash,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    addedAt: addedAt ?? this.addedAt,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      format: data.format.present ? data.format.value : this.format,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('fileHash: $fileHash, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('coverPath: $coverPath, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    format,
    filePath,
    fileHash,
    fileSizeBytes,
    coverPath,
    addedAt,
    lastReadAt,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.format == this.format &&
          other.filePath == this.filePath &&
          other.fileHash == this.fileHash &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.coverPath == this.coverPath &&
          other.addedAt == this.addedAt &&
          other.lastReadAt == this.lastReadAt &&
          other.sortOrder == this.sortOrder);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> author;
  final Value<String> format;
  final Value<String> filePath;
  final Value<String> fileHash;
  final Value<int> fileSizeBytes;
  final Value<String?> coverPath;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastReadAt;
  final Value<int?> sortOrder;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.format = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    this.author = const Value.absent(),
    required String format,
    required String filePath,
    required String fileHash,
    required int fileSizeBytes,
    this.coverPath = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       format = Value(format),
       filePath = Value(filePath),
       fileHash = Value(fileHash),
       fileSizeBytes = Value(fileSizeBytes);
  static Insertable<Book> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? format,
    Expression<String>? filePath,
    Expression<String>? fileHash,
    Expression<int>? fileSizeBytes,
    Expression<String>? coverPath,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastReadAt,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (format != null) 'format': format,
      if (filePath != null) 'file_path': filePath,
      if (fileHash != null) 'file_hash': fileHash,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (coverPath != null) 'cover_path': coverPath,
      if (addedAt != null) 'added_at': addedAt,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? author,
    Value<String>? format,
    Value<String>? filePath,
    Value<String>? fileHash,
    Value<int>? fileSizeBytes,
    Value<String?>? coverPath,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastReadAt,
    Value<int?>? sortOrder,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      fileHash: fileHash ?? this.fileHash,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      coverPath: coverPath ?? this.coverPath,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('fileHash: $fileHash, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('coverPath: $coverPath, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookTagsTable extends BookTags with TableInfo<$BookTagsTable, BookTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'REFERENCES books(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, tag};
  @override
  BookTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookTag(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $BookTagsTable createAlias(String alias) {
    return $BookTagsTable(attachedDatabase, alias);
  }
}

class BookTag extends DataClass implements Insertable<BookTag> {
  final String bookId;
  final String tag;
  const BookTag({required this.bookId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  BookTagsCompanion toCompanion(bool nullToAbsent) {
    return BookTagsCompanion(bookId: Value(bookId), tag: Value(tag));
  }

  factory BookTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookTag(
      bookId: serializer.fromJson<String>(json['bookId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  BookTag copyWith({String? bookId, String? tag}) =>
      BookTag(bookId: bookId ?? this.bookId, tag: tag ?? this.tag);
  BookTag copyWithCompanion(BookTagsCompanion data) {
    return BookTag(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookTag(')
          ..write('bookId: $bookId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookTag &&
          other.bookId == this.bookId &&
          other.tag == this.tag);
}

class BookTagsCompanion extends UpdateCompanion<BookTag> {
  final Value<String> bookId;
  final Value<String> tag;
  final Value<int> rowid;
  const BookTagsCompanion({
    this.bookId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookTagsCompanion.insert({
    required String bookId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       tag = Value(tag);
  static Insertable<BookTag> custom({
    Expression<String>? bookId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookTagsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return BookTagsCompanion(
      bookId: bookId ?? this.bookId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookTagsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookNotesTable extends BookNotes
    with TableInfo<$BookNotesTable, BookNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _keyTakeawaysMeta = const VerificationMeta(
    'keyTakeaways',
  );
  @override
  late final GeneratedColumn<String> keyTakeaways = GeneratedColumn<String>(
    'key_takeaways',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    title,
    summary,
    keyTakeaways,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('key_takeaways')) {
      context.handle(
        _keyTakeawaysMeta,
        keyTakeaways.isAcceptableOrUnknown(
          data['key_takeaways']!,
          _keyTakeawaysMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      keyTakeaways: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_takeaways'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookNotesTable createAlias(String alias) {
    return $BookNotesTable(attachedDatabase, alias);
  }
}

class BookNote extends DataClass implements Insertable<BookNote> {
  final String id;
  final String bookId;
  final String title;
  final String summary;
  final String keyTakeaways;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BookNote({
    required this.id,
    required this.bookId,
    required this.title,
    required this.summary,
    required this.keyTakeaways,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    map['key_takeaways'] = Variable<String>(keyTakeaways);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookNotesCompanion toCompanion(bool nullToAbsent) {
    return BookNotesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      title: Value(title),
      summary: Value(summary),
      keyTakeaways: Value(keyTakeaways),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookNote(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      keyTakeaways: serializer.fromJson<String>(json['keyTakeaways']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'keyTakeaways': serializer.toJson<String>(keyTakeaways),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookNote copyWith({
    String? id,
    String? bookId,
    String? title,
    String? summary,
    String? keyTakeaways,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookNote(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    keyTakeaways: keyTakeaways ?? this.keyTakeaways,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookNote copyWithCompanion(BookNotesCompanion data) {
    return BookNote(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      keyTakeaways: data.keyTakeaways.present
          ? data.keyTakeaways.value
          : this.keyTakeaways,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookNote(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('keyTakeaways: $keyTakeaways, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    title,
    summary,
    keyTakeaways,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookNote &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.keyTakeaways == this.keyTakeaways &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookNotesCompanion extends UpdateCompanion<BookNote> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> title;
  final Value<String> summary;
  final Value<String> keyTakeaways;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookNotesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.keyTakeaways = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookNotesCompanion.insert({
    required String id,
    required String bookId,
    required String title,
    this.summary = const Value.absent(),
    this.keyTakeaways = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       title = Value(title);
  static Insertable<BookNote> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? keyTakeaways,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (keyTakeaways != null) 'key_takeaways': keyTakeaways,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? title,
    Value<String>? summary,
    Value<String>? keyTakeaways,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookNotesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (keyTakeaways.present) {
      map['key_takeaways'] = Variable<String>(keyTakeaways.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookNotesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('keyTakeaways: $keyTakeaways, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnotationsTable extends Annotations
    with TableInfo<$AnnotationsTable, Annotation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookNoteIdMeta = const VerificationMeta(
    'bookNoteId',
  );
  @override
  late final GeneratedColumn<String> bookNoteId = GeneratedColumn<String>(
    'book_note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES book_notes (id)',
    ),
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteMeta = const VerificationMeta('quote');
  @override
  late final GeneratedColumn<String> quote = GeneratedColumn<String>(
    'quote',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookNoteId,
    locator,
    quote,
    note,
    color,
    tags,
    source,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Annotation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_note_id')) {
      context.handle(
        _bookNoteIdMeta,
        bookNoteId.isAcceptableOrUnknown(
          data['book_note_id']!,
          _bookNoteIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookNoteIdMeta);
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('quote')) {
      context.handle(
        _quoteMeta,
        quote.isAcceptableOrUnknown(data['quote']!, _quoteMeta),
      );
    } else if (isInserting) {
      context.missing(_quoteMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Annotation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Annotation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookNoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_note_id'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      )!,
      quote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AnnotationsTable createAlias(String alias) {
    return $AnnotationsTable(attachedDatabase, alias);
  }
}

class Annotation extends DataClass implements Insertable<Annotation> {
  final String id;
  final String bookNoteId;
  final String locator;
  final String quote;
  final String? note;
  final String color;
  final String tags;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Annotation({
    required this.id,
    required this.bookNoteId,
    required this.locator,
    required this.quote,
    this.note,
    required this.color,
    required this.tags,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_note_id'] = Variable<String>(bookNoteId);
    map['locator'] = Variable<String>(locator);
    map['quote'] = Variable<String>(quote);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['color'] = Variable<String>(color);
    map['tags'] = Variable<String>(tags);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AnnotationsCompanion toCompanion(bool nullToAbsent) {
    return AnnotationsCompanion(
      id: Value(id),
      bookNoteId: Value(bookNoteId),
      locator: Value(locator),
      quote: Value(quote),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      color: Value(color),
      tags: Value(tags),
      source: Value(source),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Annotation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Annotation(
      id: serializer.fromJson<String>(json['id']),
      bookNoteId: serializer.fromJson<String>(json['bookNoteId']),
      locator: serializer.fromJson<String>(json['locator']),
      quote: serializer.fromJson<String>(json['quote']),
      note: serializer.fromJson<String?>(json['note']),
      color: serializer.fromJson<String>(json['color']),
      tags: serializer.fromJson<String>(json['tags']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookNoteId': serializer.toJson<String>(bookNoteId),
      'locator': serializer.toJson<String>(locator),
      'quote': serializer.toJson<String>(quote),
      'note': serializer.toJson<String?>(note),
      'color': serializer.toJson<String>(color),
      'tags': serializer.toJson<String>(tags),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Annotation copyWith({
    String? id,
    String? bookNoteId,
    String? locator,
    String? quote,
    Value<String?> note = const Value.absent(),
    String? color,
    String? tags,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Annotation(
    id: id ?? this.id,
    bookNoteId: bookNoteId ?? this.bookNoteId,
    locator: locator ?? this.locator,
    quote: quote ?? this.quote,
    note: note.present ? note.value : this.note,
    color: color ?? this.color,
    tags: tags ?? this.tags,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Annotation copyWithCompanion(AnnotationsCompanion data) {
    return Annotation(
      id: data.id.present ? data.id.value : this.id,
      bookNoteId: data.bookNoteId.present
          ? data.bookNoteId.value
          : this.bookNoteId,
      locator: data.locator.present ? data.locator.value : this.locator,
      quote: data.quote.present ? data.quote.value : this.quote,
      note: data.note.present ? data.note.value : this.note,
      color: data.color.present ? data.color.value : this.color,
      tags: data.tags.present ? data.tags.value : this.tags,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Annotation(')
          ..write('id: $id, ')
          ..write('bookNoteId: $bookNoteId, ')
          ..write('locator: $locator, ')
          ..write('quote: $quote, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('tags: $tags, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookNoteId,
    locator,
    quote,
    note,
    color,
    tags,
    source,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Annotation &&
          other.id == this.id &&
          other.bookNoteId == this.bookNoteId &&
          other.locator == this.locator &&
          other.quote == this.quote &&
          other.note == this.note &&
          other.color == this.color &&
          other.tags == this.tags &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AnnotationsCompanion extends UpdateCompanion<Annotation> {
  final Value<String> id;
  final Value<String> bookNoteId;
  final Value<String> locator;
  final Value<String> quote;
  final Value<String?> note;
  final Value<String> color;
  final Value<String> tags;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AnnotationsCompanion({
    this.id = const Value.absent(),
    this.bookNoteId = const Value.absent(),
    this.locator = const Value.absent(),
    this.quote = const Value.absent(),
    this.note = const Value.absent(),
    this.color = const Value.absent(),
    this.tags = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnotationsCompanion.insert({
    required String id,
    required String bookNoteId,
    required String locator,
    required String quote,
    this.note = const Value.absent(),
    required String color,
    this.tags = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookNoteId = Value(bookNoteId),
       locator = Value(locator),
       quote = Value(quote),
       color = Value(color);
  static Insertable<Annotation> custom({
    Expression<String>? id,
    Expression<String>? bookNoteId,
    Expression<String>? locator,
    Expression<String>? quote,
    Expression<String>? note,
    Expression<String>? color,
    Expression<String>? tags,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookNoteId != null) 'book_note_id': bookNoteId,
      if (locator != null) 'locator': locator,
      if (quote != null) 'quote': quote,
      if (note != null) 'note': note,
      if (color != null) 'color': color,
      if (tags != null) 'tags': tags,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnotationsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookNoteId,
    Value<String>? locator,
    Value<String>? quote,
    Value<String?>? note,
    Value<String>? color,
    Value<String>? tags,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AnnotationsCompanion(
      id: id ?? this.id,
      bookNoteId: bookNoteId ?? this.bookNoteId,
      locator: locator ?? this.locator,
      quote: quote ?? this.quote,
      note: note ?? this.note,
      color: color ?? this.color,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookNoteId.present) {
      map['book_note_id'] = Variable<String>(bookNoteId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (quote.present) {
      map['quote'] = Variable<String>(quote.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('bookNoteId: $bookNoteId, ')
          ..write('locator: $locator, ')
          ..write('quote: $quote, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('tags: $tags, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTableTable extends ReadingProgressTable
    with TableInfo<$ReadingProgressTableTable, ReadingProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _percentMeta = const VerificationMeta(
    'percent',
  );
  @override
  late final GeneratedColumn<double> percent = GeneratedColumn<double>(
    'percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, locator, percent, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('percent')) {
      context.handle(
        _percentMeta,
        percent.isAcceptableOrUnknown(data['percent']!, _percentMeta),
      );
    } else if (isInserting) {
      context.missing(_percentMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressTableData(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      )!,
      percent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percent'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressTableTable createAlias(String alias) {
    return $ReadingProgressTableTable(attachedDatabase, alias);
  }
}

class ReadingProgressTableData extends DataClass
    implements Insertable<ReadingProgressTableData> {
  final String bookId;
  final String locator;
  final double percent;
  final DateTime updatedAt;
  const ReadingProgressTableData({
    required this.bookId,
    required this.locator,
    required this.percent,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['locator'] = Variable<String>(locator);
    map['percent'] = Variable<double>(percent);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressTableCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressTableCompanion(
      bookId: Value(bookId),
      locator: Value(locator),
      percent: Value(percent),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressTableData(
      bookId: serializer.fromJson<String>(json['bookId']),
      locator: serializer.fromJson<String>(json['locator']),
      percent: serializer.fromJson<double>(json['percent']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'locator': serializer.toJson<String>(locator),
      'percent': serializer.toJson<double>(percent),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressTableData copyWith({
    String? bookId,
    String? locator,
    double? percent,
    DateTime? updatedAt,
  }) => ReadingProgressTableData(
    bookId: bookId ?? this.bookId,
    locator: locator ?? this.locator,
    percent: percent ?? this.percent,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressTableData copyWithCompanion(
    ReadingProgressTableCompanion data,
  ) {
    return ReadingProgressTableData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      locator: data.locator.present ? data.locator.value : this.locator,
      percent: data.percent.present ? data.percent.value : this.percent,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressTableData(')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('percent: $percent, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, locator, percent, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressTableData &&
          other.bookId == this.bookId &&
          other.locator == this.locator &&
          other.percent == this.percent &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressTableCompanion
    extends UpdateCompanion<ReadingProgressTableData> {
  final Value<String> bookId;
  final Value<String> locator;
  final Value<double> percent;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingProgressTableCompanion({
    this.bookId = const Value.absent(),
    this.locator = const Value.absent(),
    this.percent = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressTableCompanion.insert({
    required String bookId,
    required String locator,
    required double percent,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       locator = Value(locator),
       percent = Value(percent);
  static Insertable<ReadingProgressTableData> custom({
    Expression<String>? bookId,
    Expression<String>? locator,
    Expression<double>? percent,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (locator != null) 'locator': locator,
      if (percent != null) 'percent': percent,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressTableCompanion copyWith({
    Value<String>? bookId,
    Value<String>? locator,
    Value<double>? percent,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReadingProgressTableCompanion(
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      percent: percent ?? this.percent,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (percent.present) {
      map['percent'] = Variable<double>(percent.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressTableCompanion(')
          ..write('bookId: $bookId, ')
          ..write('locator: $locator, ')
          ..write('percent: $percent, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TypographyProfilesTable extends TypographyProfiles
    with TableInfo<$TypographyProfilesTable, TypographyProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TypographyProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingsMeta = const VerificationMeta(
    'settings',
  );
  @override
  late final GeneratedColumn<String> settings = GeneratedColumn<String>(
    'settings',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, settings, isDefault];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'typography_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<TypographyProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('settings')) {
      context.handle(
        _settingsMeta,
        settings.isAcceptableOrUnknown(data['settings']!, _settingsMeta),
      );
    } else if (isInserting) {
      context.missing(_settingsMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TypographyProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TypographyProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      settings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $TypographyProfilesTable createAlias(String alias) {
    return $TypographyProfilesTable(attachedDatabase, alias);
  }
}

class TypographyProfile extends DataClass
    implements Insertable<TypographyProfile> {
  final String id;
  final String name;
  final String settings;
  final bool isDefault;
  const TypographyProfile({
    required this.id,
    required this.name,
    required this.settings,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['settings'] = Variable<String>(settings);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  TypographyProfilesCompanion toCompanion(bool nullToAbsent) {
    return TypographyProfilesCompanion(
      id: Value(id),
      name: Value(name),
      settings: Value(settings),
      isDefault: Value(isDefault),
    );
  }

  factory TypographyProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TypographyProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      settings: serializer.fromJson<String>(json['settings']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'settings': serializer.toJson<String>(settings),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  TypographyProfile copyWith({
    String? id,
    String? name,
    String? settings,
    bool? isDefault,
  }) => TypographyProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    settings: settings ?? this.settings,
    isDefault: isDefault ?? this.isDefault,
  );
  TypographyProfile copyWithCompanion(TypographyProfilesCompanion data) {
    return TypographyProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      settings: data.settings.present ? data.settings.value : this.settings,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TypographyProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('settings: $settings, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, settings, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TypographyProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.settings == this.settings &&
          other.isDefault == this.isDefault);
}

class TypographyProfilesCompanion extends UpdateCompanion<TypographyProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> settings;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const TypographyProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.settings = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TypographyProfilesCompanion.insert({
    required String id,
    required String name,
    required String settings,
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       settings = Value(settings);
  static Insertable<TypographyProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? settings,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (settings != null) 'settings': settings,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TypographyProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? settings,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return TypographyProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (settings.present) {
      map['settings'] = Variable<String>(settings.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TypographyProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('settings: $settings, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookTypographyOverridesTable extends BookTypographyOverrides
    with TableInfo<$BookTypographyOverridesTable, BookTypographyOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookTypographyOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customSettingsMeta = const VerificationMeta(
    'customSettings',
  );
  @override
  late final GeneratedColumn<String> customSettings = GeneratedColumn<String>(
    'custom_settings',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, profileId, customSettings];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_typography_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookTypographyOverride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('custom_settings')) {
      context.handle(
        _customSettingsMeta,
        customSettings.isAcceptableOrUnknown(
          data['custom_settings']!,
          _customSettingsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  BookTypographyOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookTypographyOverride(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      ),
      customSettings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_settings'],
      ),
    );
  }

  @override
  $BookTypographyOverridesTable createAlias(String alias) {
    return $BookTypographyOverridesTable(attachedDatabase, alias);
  }
}

class BookTypographyOverride extends DataClass
    implements Insertable<BookTypographyOverride> {
  final String bookId;
  final String? profileId;
  final String? customSettings;
  const BookTypographyOverride({
    required this.bookId,
    this.profileId,
    this.customSettings,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<String>(profileId);
    }
    if (!nullToAbsent || customSettings != null) {
      map['custom_settings'] = Variable<String>(customSettings);
    }
    return map;
  }

  BookTypographyOverridesCompanion toCompanion(bool nullToAbsent) {
    return BookTypographyOverridesCompanion(
      bookId: Value(bookId),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      customSettings: customSettings == null && nullToAbsent
          ? const Value.absent()
          : Value(customSettings),
    );
  }

  factory BookTypographyOverride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookTypographyOverride(
      bookId: serializer.fromJson<String>(json['bookId']),
      profileId: serializer.fromJson<String?>(json['profileId']),
      customSettings: serializer.fromJson<String?>(json['customSettings']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'profileId': serializer.toJson<String?>(profileId),
      'customSettings': serializer.toJson<String?>(customSettings),
    };
  }

  BookTypographyOverride copyWith({
    String? bookId,
    Value<String?> profileId = const Value.absent(),
    Value<String?> customSettings = const Value.absent(),
  }) => BookTypographyOverride(
    bookId: bookId ?? this.bookId,
    profileId: profileId.present ? profileId.value : this.profileId,
    customSettings: customSettings.present
        ? customSettings.value
        : this.customSettings,
  );
  BookTypographyOverride copyWithCompanion(
    BookTypographyOverridesCompanion data,
  ) {
    return BookTypographyOverride(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      customSettings: data.customSettings.present
          ? data.customSettings.value
          : this.customSettings,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookTypographyOverride(')
          ..write('bookId: $bookId, ')
          ..write('profileId: $profileId, ')
          ..write('customSettings: $customSettings')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, profileId, customSettings);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookTypographyOverride &&
          other.bookId == this.bookId &&
          other.profileId == this.profileId &&
          other.customSettings == this.customSettings);
}

class BookTypographyOverridesCompanion
    extends UpdateCompanion<BookTypographyOverride> {
  final Value<String> bookId;
  final Value<String?> profileId;
  final Value<String?> customSettings;
  final Value<int> rowid;
  const BookTypographyOverridesCompanion({
    this.bookId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.customSettings = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookTypographyOverridesCompanion.insert({
    required String bookId,
    this.profileId = const Value.absent(),
    this.customSettings = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId);
  static Insertable<BookTypographyOverride> custom({
    Expression<String>? bookId,
    Expression<String>? profileId,
    Expression<String>? customSettings,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (profileId != null) 'profile_id': profileId,
      if (customSettings != null) 'custom_settings': customSettings,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookTypographyOverridesCompanion copyWith({
    Value<String>? bookId,
    Value<String?>? profileId,
    Value<String?>? customSettings,
    Value<int>? rowid,
  }) {
    return BookTypographyOverridesCompanion(
      bookId: bookId ?? this.bookId,
      profileId: profileId ?? this.profileId,
      customSettings: customSettings ?? this.customSettings,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (customSettings.present) {
      map['custom_settings'] = Variable<String>(customSettings.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookTypographyOverridesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('profileId: $profileId, ')
          ..write('customSettings: $customSettings, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserFontsTable extends UserFonts
    with TableInfo<$UserFontsTable, UserFont> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserFontsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyNameMeta = const VerificationMeta(
    'familyName',
  );
  @override
  late final GeneratedColumn<String> familyName = GeneratedColumn<String>(
    'family_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashSha1Meta = const VerificationMeta(
    'hashSha1',
  );
  @override
  late final GeneratedColumn<String> hashSha1 = GeneratedColumn<String>(
    'hash_sha1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _absolutePathMeta = const VerificationMeta(
    'absolutePath',
  );
  @override
  late final GeneratedColumn<String> absolutePath = GeneratedColumn<String>(
    'absolute_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    fileName,
    familyName,
    hashSha1,
    absolutePath,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_fonts';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserFont> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('family_name')) {
      context.handle(
        _familyNameMeta,
        familyName.isAcceptableOrUnknown(data['family_name']!, _familyNameMeta),
      );
    } else if (isInserting) {
      context.missing(_familyNameMeta);
    }
    if (data.containsKey('hash_sha1')) {
      context.handle(
        _hashSha1Meta,
        hashSha1.isAcceptableOrUnknown(data['hash_sha1']!, _hashSha1Meta),
      );
    } else if (isInserting) {
      context.missing(_hashSha1Meta);
    }
    if (data.containsKey('absolute_path')) {
      context.handle(
        _absolutePathMeta,
        absolutePath.isAcceptableOrUnknown(
          data['absolute_path']!,
          _absolutePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_absolutePathMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserFont map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserFont(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      familyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_name'],
      )!,
      hashSha1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash_sha1'],
      )!,
      absolutePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}absolute_path'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $UserFontsTable createAlias(String alias) {
    return $UserFontsTable(attachedDatabase, alias);
  }
}

class UserFont extends DataClass implements Insertable<UserFont> {
  final String id;
  final String displayName;
  final String fileName;
  final String familyName;
  final String hashSha1;
  final String absolutePath;
  final DateTime addedAt;
  const UserFont({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.familyName,
    required this.hashSha1,
    required this.absolutePath,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['file_name'] = Variable<String>(fileName);
    map['family_name'] = Variable<String>(familyName);
    map['hash_sha1'] = Variable<String>(hashSha1);
    map['absolute_path'] = Variable<String>(absolutePath);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  UserFontsCompanion toCompanion(bool nullToAbsent) {
    return UserFontsCompanion(
      id: Value(id),
      displayName: Value(displayName),
      fileName: Value(fileName),
      familyName: Value(familyName),
      hashSha1: Value(hashSha1),
      absolutePath: Value(absolutePath),
      addedAt: Value(addedAt),
    );
  }

  factory UserFont.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserFont(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      fileName: serializer.fromJson<String>(json['fileName']),
      familyName: serializer.fromJson<String>(json['familyName']),
      hashSha1: serializer.fromJson<String>(json['hashSha1']),
      absolutePath: serializer.fromJson<String>(json['absolutePath']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'fileName': serializer.toJson<String>(fileName),
      'familyName': serializer.toJson<String>(familyName),
      'hashSha1': serializer.toJson<String>(hashSha1),
      'absolutePath': serializer.toJson<String>(absolutePath),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  UserFont copyWith({
    String? id,
    String? displayName,
    String? fileName,
    String? familyName,
    String? hashSha1,
    String? absolutePath,
    DateTime? addedAt,
  }) => UserFont(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    fileName: fileName ?? this.fileName,
    familyName: familyName ?? this.familyName,
    hashSha1: hashSha1 ?? this.hashSha1,
    absolutePath: absolutePath ?? this.absolutePath,
    addedAt: addedAt ?? this.addedAt,
  );
  UserFont copyWithCompanion(UserFontsCompanion data) {
    return UserFont(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      familyName: data.familyName.present
          ? data.familyName.value
          : this.familyName,
      hashSha1: data.hashSha1.present ? data.hashSha1.value : this.hashSha1,
      absolutePath: data.absolutePath.present
          ? data.absolutePath.value
          : this.absolutePath,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserFont(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('fileName: $fileName, ')
          ..write('familyName: $familyName, ')
          ..write('hashSha1: $hashSha1, ')
          ..write('absolutePath: $absolutePath, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    fileName,
    familyName,
    hashSha1,
    absolutePath,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserFont &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.fileName == this.fileName &&
          other.familyName == this.familyName &&
          other.hashSha1 == this.hashSha1 &&
          other.absolutePath == this.absolutePath &&
          other.addedAt == this.addedAt);
}

class UserFontsCompanion extends UpdateCompanion<UserFont> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> fileName;
  final Value<String> familyName;
  final Value<String> hashSha1;
  final Value<String> absolutePath;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const UserFontsCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.fileName = const Value.absent(),
    this.familyName = const Value.absent(),
    this.hashSha1 = const Value.absent(),
    this.absolutePath = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserFontsCompanion.insert({
    required String id,
    required String displayName,
    required String fileName,
    required String familyName,
    required String hashSha1,
    required String absolutePath,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       fileName = Value(fileName),
       familyName = Value(familyName),
       hashSha1 = Value(hashSha1),
       absolutePath = Value(absolutePath);
  static Insertable<UserFont> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? fileName,
    Expression<String>? familyName,
    Expression<String>? hashSha1,
    Expression<String>? absolutePath,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (fileName != null) 'file_name': fileName,
      if (familyName != null) 'family_name': familyName,
      if (hashSha1 != null) 'hash_sha1': hashSha1,
      if (absolutePath != null) 'absolute_path': absolutePath,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserFontsCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? fileName,
    Value<String>? familyName,
    Value<String>? hashSha1,
    Value<String>? absolutePath,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return UserFontsCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      fileName: fileName ?? this.fileName,
      familyName: familyName ?? this.familyName,
      hashSha1: hashSha1 ?? this.hashSha1,
      absolutePath: absolutePath ?? this.absolutePath,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (familyName.present) {
      map['family_name'] = Variable<String>(familyName.value);
    }
    if (hashSha1.present) {
      map['hash_sha1'] = Variable<String>(hashSha1.value);
    }
    if (absolutePath.present) {
      map['absolute_path'] = Variable<String>(absolutePath.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserFontsCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('fileName: $fileName, ')
          ..write('familyName: $familyName, ')
          ..write('hashSha1: $hashSha1, ')
          ..write('absolutePath: $absolutePath, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordTypeMeta = const VerificationMeta(
    'recordType',
  );
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
    'record_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _pushedAtMeta = const VerificationMeta(
    'pushedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pushedAt = GeneratedColumn<DateTime>(
    'pushed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordId,
    recordType,
    payloadJson,
    queuedAt,
    pushedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
        _recordTypeMeta,
        recordType.isAcceptableOrUnknown(data['record_type']!, _recordTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    }
    if (data.containsKey('pushed_at')) {
      context.handle(
        _pushedAtMeta,
        pushedAt.isAcceptableOrUnknown(data['pushed_at']!, _pushedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      recordType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      pushedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pushed_at'],
      ),
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final int id;
  final String recordId;
  final String recordType;
  final String payloadJson;
  final DateTime queuedAt;
  final DateTime? pushedAt;
  const SyncOutboxData({
    required this.id,
    required this.recordId,
    required this.recordType,
    required this.payloadJson,
    required this.queuedAt,
    this.pushedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record_id'] = Variable<String>(recordId);
    map['record_type'] = Variable<String>(recordType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    if (!nullToAbsent || pushedAt != null) {
      map['pushed_at'] = Variable<DateTime>(pushedAt);
    }
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      recordId: Value(recordId),
      recordType: Value(recordType),
      payloadJson: Value(payloadJson),
      queuedAt: Value(queuedAt),
      pushedAt: pushedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pushedAt),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      id: serializer.fromJson<int>(json['id']),
      recordId: serializer.fromJson<String>(json['recordId']),
      recordType: serializer.fromJson<String>(json['recordType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      pushedAt: serializer.fromJson<DateTime?>(json['pushedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordId': serializer.toJson<String>(recordId),
      'recordType': serializer.toJson<String>(recordType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'pushedAt': serializer.toJson<DateTime?>(pushedAt),
    };
  }

  SyncOutboxData copyWith({
    int? id,
    String? recordId,
    String? recordType,
    String? payloadJson,
    DateTime? queuedAt,
    Value<DateTime?> pushedAt = const Value.absent(),
  }) => SyncOutboxData(
    id: id ?? this.id,
    recordId: recordId ?? this.recordId,
    recordType: recordType ?? this.recordType,
    payloadJson: payloadJson ?? this.payloadJson,
    queuedAt: queuedAt ?? this.queuedAt,
    pushedAt: pushedAt.present ? pushedAt.value : this.pushedAt,
  );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      id: data.id.present ? data.id.value : this.id,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      recordType: data.recordType.present
          ? data.recordType.value
          : this.recordType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      pushedAt: data.pushedAt.present ? data.pushedAt.value : this.pushedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('recordType: $recordType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, recordId, recordType, payloadJson, queuedAt, pushedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.id == this.id &&
          other.recordId == this.recordId &&
          other.recordType == this.recordType &&
          other.payloadJson == this.payloadJson &&
          other.queuedAt == this.queuedAt &&
          other.pushedAt == this.pushedAt);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<int> id;
  final Value<String> recordId;
  final Value<String> recordType;
  final Value<String> payloadJson;
  final Value<DateTime> queuedAt;
  final Value<DateTime?> pushedAt;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.recordId = const Value.absent(),
    this.recordType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.pushedAt = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String recordId,
    required String recordType,
    required String payloadJson,
    this.queuedAt = const Value.absent(),
    this.pushedAt = const Value.absent(),
  }) : recordId = Value(recordId),
       recordType = Value(recordType),
       payloadJson = Value(payloadJson);
  static Insertable<SyncOutboxData> custom({
    Expression<int>? id,
    Expression<String>? recordId,
    Expression<String>? recordType,
    Expression<String>? payloadJson,
    Expression<DateTime>? queuedAt,
    Expression<DateTime>? pushedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      if (recordType != null) 'record_type': recordType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (pushedAt != null) 'pushed_at': pushedAt,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? recordId,
    Value<String>? recordType,
    Value<String>? payloadJson,
    Value<DateTime>? queuedAt,
    Value<DateTime?>? pushedAt,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      recordType: recordType ?? this.recordType,
      payloadJson: payloadJson ?? this.payloadJson,
      queuedAt: queuedAt ?? this.queuedAt,
      pushedAt: pushedAt ?? this.pushedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (pushedAt.present) {
      map['pushed_at'] = Variable<DateTime>(pushedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('recordType: $recordType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }
}

class $AiSummariesTable extends AiSummaries
    with TableInfo<$AiSummariesTable, AiSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceHashMeta = const VerificationMeta(
    'sourceHash',
  );
  @override
  late final GeneratedColumn<String> sourceHash = GeneratedColumn<String>(
    'source_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryTextMeta = const VerificationMeta(
    'summaryText',
  );
  @override
  late final GeneratedColumn<String> summaryText = GeneratedColumn<String>(
    'summary_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _promptVersionMeta = const VerificationMeta(
    'promptVersion',
  );
  @override
  late final GeneratedColumn<int> promptVersion = GeneratedColumn<int>(
    'prompt_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    mode,
    sourceHash,
    summaryText,
    modelName,
    baseUrl,
    generatedAt,
    promptVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiSummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('source_hash')) {
      context.handle(
        _sourceHashMeta,
        sourceHash.isAcceptableOrUnknown(data['source_hash']!, _sourceHashMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceHashMeta);
    }
    if (data.containsKey('summary_text')) {
      context.handle(
        _summaryTextMeta,
        summaryText.isAcceptableOrUnknown(
          data['summary_text']!,
          _summaryTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryTextMeta);
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
      );
    } else if (isInserting) {
      context.missing(_modelNameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    }
    if (data.containsKey('prompt_version')) {
      context.handle(
        _promptVersionMeta,
        promptVersion.isAcceptableOrUnknown(
          data['prompt_version']!,
          _promptVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_promptVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiSummary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      sourceHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_hash'],
      )!,
      summaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_text'],
      )!,
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
      promptVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prompt_version'],
      )!,
    );
  }

  @override
  $AiSummariesTable createAlias(String alias) {
    return $AiSummariesTable(attachedDatabase, alias);
  }
}

class AiSummary extends DataClass implements Insertable<AiSummary> {
  final int id;
  final String bookId;
  final String mode;
  final String sourceHash;
  final String summaryText;
  final String modelName;
  final String baseUrl;
  final DateTime generatedAt;
  final int promptVersion;
  const AiSummary({
    required this.id,
    required this.bookId,
    required this.mode,
    required this.sourceHash,
    required this.summaryText,
    required this.modelName,
    required this.baseUrl,
    required this.generatedAt,
    required this.promptVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['mode'] = Variable<String>(mode);
    map['source_hash'] = Variable<String>(sourceHash);
    map['summary_text'] = Variable<String>(summaryText);
    map['model_name'] = Variable<String>(modelName);
    map['base_url'] = Variable<String>(baseUrl);
    map['generated_at'] = Variable<DateTime>(generatedAt);
    map['prompt_version'] = Variable<int>(promptVersion);
    return map;
  }

  AiSummariesCompanion toCompanion(bool nullToAbsent) {
    return AiSummariesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      mode: Value(mode),
      sourceHash: Value(sourceHash),
      summaryText: Value(summaryText),
      modelName: Value(modelName),
      baseUrl: Value(baseUrl),
      generatedAt: Value(generatedAt),
      promptVersion: Value(promptVersion),
    );
  }

  factory AiSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiSummary(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      mode: serializer.fromJson<String>(json['mode']),
      sourceHash: serializer.fromJson<String>(json['sourceHash']),
      summaryText: serializer.fromJson<String>(json['summaryText']),
      modelName: serializer.fromJson<String>(json['modelName']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      promptVersion: serializer.fromJson<int>(json['promptVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'mode': serializer.toJson<String>(mode),
      'sourceHash': serializer.toJson<String>(sourceHash),
      'summaryText': serializer.toJson<String>(summaryText),
      'modelName': serializer.toJson<String>(modelName),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'promptVersion': serializer.toJson<int>(promptVersion),
    };
  }

  AiSummary copyWith({
    int? id,
    String? bookId,
    String? mode,
    String? sourceHash,
    String? summaryText,
    String? modelName,
    String? baseUrl,
    DateTime? generatedAt,
    int? promptVersion,
  }) => AiSummary(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    mode: mode ?? this.mode,
    sourceHash: sourceHash ?? this.sourceHash,
    summaryText: summaryText ?? this.summaryText,
    modelName: modelName ?? this.modelName,
    baseUrl: baseUrl ?? this.baseUrl,
    generatedAt: generatedAt ?? this.generatedAt,
    promptVersion: promptVersion ?? this.promptVersion,
  );
  AiSummary copyWithCompanion(AiSummariesCompanion data) {
    return AiSummary(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      mode: data.mode.present ? data.mode.value : this.mode,
      sourceHash: data.sourceHash.present
          ? data.sourceHash.value
          : this.sourceHash,
      summaryText: data.summaryText.present
          ? data.summaryText.value
          : this.summaryText,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      promptVersion: data.promptVersion.present
          ? data.promptVersion.value
          : this.promptVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiSummary(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('mode: $mode, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('summaryText: $summaryText, ')
          ..write('modelName: $modelName, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('promptVersion: $promptVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    mode,
    sourceHash,
    summaryText,
    modelName,
    baseUrl,
    generatedAt,
    promptVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiSummary &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.mode == this.mode &&
          other.sourceHash == this.sourceHash &&
          other.summaryText == this.summaryText &&
          other.modelName == this.modelName &&
          other.baseUrl == this.baseUrl &&
          other.generatedAt == this.generatedAt &&
          other.promptVersion == this.promptVersion);
}

class AiSummariesCompanion extends UpdateCompanion<AiSummary> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> mode;
  final Value<String> sourceHash;
  final Value<String> summaryText;
  final Value<String> modelName;
  final Value<String> baseUrl;
  final Value<DateTime> generatedAt;
  final Value<int> promptVersion;
  const AiSummariesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.mode = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.summaryText = const Value.absent(),
    this.modelName = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.promptVersion = const Value.absent(),
  });
  AiSummariesCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String mode,
    required String sourceHash,
    required String summaryText,
    required String modelName,
    required String baseUrl,
    this.generatedAt = const Value.absent(),
    required int promptVersion,
  }) : bookId = Value(bookId),
       mode = Value(mode),
       sourceHash = Value(sourceHash),
       summaryText = Value(summaryText),
       modelName = Value(modelName),
       baseUrl = Value(baseUrl),
       promptVersion = Value(promptVersion);
  static Insertable<AiSummary> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? mode,
    Expression<String>? sourceHash,
    Expression<String>? summaryText,
    Expression<String>? modelName,
    Expression<String>? baseUrl,
    Expression<DateTime>? generatedAt,
    Expression<int>? promptVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (mode != null) 'mode': mode,
      if (sourceHash != null) 'source_hash': sourceHash,
      if (summaryText != null) 'summary_text': summaryText,
      if (modelName != null) 'model_name': modelName,
      if (baseUrl != null) 'base_url': baseUrl,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (promptVersion != null) 'prompt_version': promptVersion,
    });
  }

  AiSummariesCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<String>? mode,
    Value<String>? sourceHash,
    Value<String>? summaryText,
    Value<String>? modelName,
    Value<String>? baseUrl,
    Value<DateTime>? generatedAt,
    Value<int>? promptVersion,
  }) {
    return AiSummariesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      mode: mode ?? this.mode,
      sourceHash: sourceHash ?? this.sourceHash,
      summaryText: summaryText ?? this.summaryText,
      modelName: modelName ?? this.modelName,
      baseUrl: baseUrl ?? this.baseUrl,
      generatedAt: generatedAt ?? this.generatedAt,
      promptVersion: promptVersion ?? this.promptVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (sourceHash.present) {
      map['source_hash'] = Variable<String>(sourceHash.value);
    }
    if (summaryText.present) {
      map['summary_text'] = Variable<String>(summaryText.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (promptVersion.present) {
      map['prompt_version'] = Variable<int>(promptVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiSummariesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('mode: $mode, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('summaryText: $summaryText, ')
          ..write('modelName: $modelName, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('promptVersion: $promptVersion')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordTypeMeta = const VerificationMeta(
    'recordType',
  );
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
    'record_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localMtimeMeta = const VerificationMeta(
    'localMtime',
  );
  @override
  late final GeneratedColumn<DateTime> localMtime = GeneratedColumn<DateTime>(
    'local_mtime',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteMtimeMeta = const VerificationMeta(
    'remoteMtime',
  );
  @override
  late final GeneratedColumn<DateTime> remoteMtime = GeneratedColumn<DateTime>(
    'remote_mtime',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _winnerDeviceMeta = const VerificationMeta(
    'winnerDevice',
  );
  @override
  late final GeneratedColumn<String> winnerDevice = GeneratedColumn<String>(
    'winner_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loserDeviceMeta = const VerificationMeta(
    'loserDevice',
  );
  @override
  late final GeneratedColumn<String> loserDevice = GeneratedColumn<String>(
    'loser_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadPreviewMeta = const VerificationMeta(
    'payloadPreview',
  );
  @override
  late final GeneratedColumn<String> payloadPreview = GeneratedColumn<String>(
    'payload_preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordId,
    recordType,
    localMtime,
    remoteMtime,
    winnerDevice,
    loserDevice,
    detectedAt,
    payloadPreview,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
        _recordTypeMeta,
        recordType.isAcceptableOrUnknown(data['record_type']!, _recordTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('local_mtime')) {
      context.handle(
        _localMtimeMeta,
        localMtime.isAcceptableOrUnknown(data['local_mtime']!, _localMtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_localMtimeMeta);
    }
    if (data.containsKey('remote_mtime')) {
      context.handle(
        _remoteMtimeMeta,
        remoteMtime.isAcceptableOrUnknown(
          data['remote_mtime']!,
          _remoteMtimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteMtimeMeta);
    }
    if (data.containsKey('winner_device')) {
      context.handle(
        _winnerDeviceMeta,
        winnerDevice.isAcceptableOrUnknown(
          data['winner_device']!,
          _winnerDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_winnerDeviceMeta);
    }
    if (data.containsKey('loser_device')) {
      context.handle(
        _loserDeviceMeta,
        loserDevice.isAcceptableOrUnknown(
          data['loser_device']!,
          _loserDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_loserDeviceMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    if (data.containsKey('payload_preview')) {
      context.handle(
        _payloadPreviewMeta,
        payloadPreview.isAcceptableOrUnknown(
          data['payload_preview']!,
          _payloadPreviewMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadPreviewMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      recordType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_type'],
      )!,
      localMtime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_mtime'],
      )!,
      remoteMtime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_mtime'],
      )!,
      winnerDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}winner_device'],
      )!,
      loserDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loser_device'],
      )!,
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}detected_at'],
      )!,
      payloadPreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_preview'],
      )!,
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflict extends DataClass implements Insertable<SyncConflict> {
  final int id;
  final String recordId;
  final String recordType;
  final DateTime localMtime;
  final DateTime remoteMtime;
  final String winnerDevice;
  final String loserDevice;
  final DateTime detectedAt;
  final String payloadPreview;
  const SyncConflict({
    required this.id,
    required this.recordId,
    required this.recordType,
    required this.localMtime,
    required this.remoteMtime,
    required this.winnerDevice,
    required this.loserDevice,
    required this.detectedAt,
    required this.payloadPreview,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record_id'] = Variable<String>(recordId);
    map['record_type'] = Variable<String>(recordType);
    map['local_mtime'] = Variable<DateTime>(localMtime);
    map['remote_mtime'] = Variable<DateTime>(remoteMtime);
    map['winner_device'] = Variable<String>(winnerDevice);
    map['loser_device'] = Variable<String>(loserDevice);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    map['payload_preview'] = Variable<String>(payloadPreview);
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      recordId: Value(recordId),
      recordType: Value(recordType),
      localMtime: Value(localMtime),
      remoteMtime: Value(remoteMtime),
      winnerDevice: Value(winnerDevice),
      loserDevice: Value(loserDevice),
      detectedAt: Value(detectedAt),
      payloadPreview: Value(payloadPreview),
    );
  }

  factory SyncConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflict(
      id: serializer.fromJson<int>(json['id']),
      recordId: serializer.fromJson<String>(json['recordId']),
      recordType: serializer.fromJson<String>(json['recordType']),
      localMtime: serializer.fromJson<DateTime>(json['localMtime']),
      remoteMtime: serializer.fromJson<DateTime>(json['remoteMtime']),
      winnerDevice: serializer.fromJson<String>(json['winnerDevice']),
      loserDevice: serializer.fromJson<String>(json['loserDevice']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
      payloadPreview: serializer.fromJson<String>(json['payloadPreview']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordId': serializer.toJson<String>(recordId),
      'recordType': serializer.toJson<String>(recordType),
      'localMtime': serializer.toJson<DateTime>(localMtime),
      'remoteMtime': serializer.toJson<DateTime>(remoteMtime),
      'winnerDevice': serializer.toJson<String>(winnerDevice),
      'loserDevice': serializer.toJson<String>(loserDevice),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
      'payloadPreview': serializer.toJson<String>(payloadPreview),
    };
  }

  SyncConflict copyWith({
    int? id,
    String? recordId,
    String? recordType,
    DateTime? localMtime,
    DateTime? remoteMtime,
    String? winnerDevice,
    String? loserDevice,
    DateTime? detectedAt,
    String? payloadPreview,
  }) => SyncConflict(
    id: id ?? this.id,
    recordId: recordId ?? this.recordId,
    recordType: recordType ?? this.recordType,
    localMtime: localMtime ?? this.localMtime,
    remoteMtime: remoteMtime ?? this.remoteMtime,
    winnerDevice: winnerDevice ?? this.winnerDevice,
    loserDevice: loserDevice ?? this.loserDevice,
    detectedAt: detectedAt ?? this.detectedAt,
    payloadPreview: payloadPreview ?? this.payloadPreview,
  );
  SyncConflict copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflict(
      id: data.id.present ? data.id.value : this.id,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      recordType: data.recordType.present
          ? data.recordType.value
          : this.recordType,
      localMtime: data.localMtime.present
          ? data.localMtime.value
          : this.localMtime,
      remoteMtime: data.remoteMtime.present
          ? data.remoteMtime.value
          : this.remoteMtime,
      winnerDevice: data.winnerDevice.present
          ? data.winnerDevice.value
          : this.winnerDevice,
      loserDevice: data.loserDevice.present
          ? data.loserDevice.value
          : this.loserDevice,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
      payloadPreview: data.payloadPreview.present
          ? data.payloadPreview.value
          : this.payloadPreview,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflict(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('recordType: $recordType, ')
          ..write('localMtime: $localMtime, ')
          ..write('remoteMtime: $remoteMtime, ')
          ..write('winnerDevice: $winnerDevice, ')
          ..write('loserDevice: $loserDevice, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('payloadPreview: $payloadPreview')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordId,
    recordType,
    localMtime,
    remoteMtime,
    winnerDevice,
    loserDevice,
    detectedAt,
    payloadPreview,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflict &&
          other.id == this.id &&
          other.recordId == this.recordId &&
          other.recordType == this.recordType &&
          other.localMtime == this.localMtime &&
          other.remoteMtime == this.remoteMtime &&
          other.winnerDevice == this.winnerDevice &&
          other.loserDevice == this.loserDevice &&
          other.detectedAt == this.detectedAt &&
          other.payloadPreview == this.payloadPreview);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflict> {
  final Value<int> id;
  final Value<String> recordId;
  final Value<String> recordType;
  final Value<DateTime> localMtime;
  final Value<DateTime> remoteMtime;
  final Value<String> winnerDevice;
  final Value<String> loserDevice;
  final Value<DateTime> detectedAt;
  final Value<String> payloadPreview;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.recordId = const Value.absent(),
    this.recordType = const Value.absent(),
    this.localMtime = const Value.absent(),
    this.remoteMtime = const Value.absent(),
    this.winnerDevice = const Value.absent(),
    this.loserDevice = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.payloadPreview = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    this.id = const Value.absent(),
    required String recordId,
    required String recordType,
    required DateTime localMtime,
    required DateTime remoteMtime,
    required String winnerDevice,
    required String loserDevice,
    required DateTime detectedAt,
    required String payloadPreview,
  }) : recordId = Value(recordId),
       recordType = Value(recordType),
       localMtime = Value(localMtime),
       remoteMtime = Value(remoteMtime),
       winnerDevice = Value(winnerDevice),
       loserDevice = Value(loserDevice),
       detectedAt = Value(detectedAt),
       payloadPreview = Value(payloadPreview);
  static Insertable<SyncConflict> custom({
    Expression<int>? id,
    Expression<String>? recordId,
    Expression<String>? recordType,
    Expression<DateTime>? localMtime,
    Expression<DateTime>? remoteMtime,
    Expression<String>? winnerDevice,
    Expression<String>? loserDevice,
    Expression<DateTime>? detectedAt,
    Expression<String>? payloadPreview,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      if (recordType != null) 'record_type': recordType,
      if (localMtime != null) 'local_mtime': localMtime,
      if (remoteMtime != null) 'remote_mtime': remoteMtime,
      if (winnerDevice != null) 'winner_device': winnerDevice,
      if (loserDevice != null) 'loser_device': loserDevice,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (payloadPreview != null) 'payload_preview': payloadPreview,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<int>? id,
    Value<String>? recordId,
    Value<String>? recordType,
    Value<DateTime>? localMtime,
    Value<DateTime>? remoteMtime,
    Value<String>? winnerDevice,
    Value<String>? loserDevice,
    Value<DateTime>? detectedAt,
    Value<String>? payloadPreview,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      recordType: recordType ?? this.recordType,
      localMtime: localMtime ?? this.localMtime,
      remoteMtime: remoteMtime ?? this.remoteMtime,
      winnerDevice: winnerDevice ?? this.winnerDevice,
      loserDevice: loserDevice ?? this.loserDevice,
      detectedAt: detectedAt ?? this.detectedAt,
      payloadPreview: payloadPreview ?? this.payloadPreview,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (localMtime.present) {
      map['local_mtime'] = Variable<DateTime>(localMtime.value);
    }
    if (remoteMtime.present) {
      map['remote_mtime'] = Variable<DateTime>(remoteMtime.value);
    }
    if (winnerDevice.present) {
      map['winner_device'] = Variable<String>(winnerDevice.value);
    }
    if (loserDevice.present) {
      map['loser_device'] = Variable<String>(loserDevice.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (payloadPreview.present) {
      map['payload_preview'] = Variable<String>(payloadPreview.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('recordType: $recordType, ')
          ..write('localMtime: $localMtime, ')
          ..write('remoteMtime: $remoteMtime, ')
          ..write('winnerDevice: $winnerDevice, ')
          ..write('loserDevice: $loserDevice, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('payloadPreview: $payloadPreview')
          ..write(')'))
        .toString();
  }
}

class $BookPassagesTable extends BookPassages
    with TableInfo<$BookPassagesTable, BookPassage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookPassagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _charOffsetMeta = const VerificationMeta(
    'charOffset',
  );
  @override
  late final GeneratedColumn<int> charOffset = GeneratedColumn<int>(
    'char_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _charLengthMeta = const VerificationMeta(
    'charLength',
  );
  @override
  late final GeneratedColumn<int> charLength = GeneratedColumn<int>(
    'char_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentTextMeta = const VerificationMeta(
    'contentText',
  );
  @override
  late final GeneratedColumn<String> contentText = GeneratedColumn<String>(
    'content_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenEstimateMeta = const VerificationMeta(
    'tokenEstimate',
  );
  @override
  late final GeneratedColumn<int> tokenEstimate = GeneratedColumn<int>(
    'token_estimate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    charOffset,
    charLength,
    contentText,
    tokenEstimate,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_passages';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookPassage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('char_offset')) {
      context.handle(
        _charOffsetMeta,
        charOffset.isAcceptableOrUnknown(data['char_offset']!, _charOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_charOffsetMeta);
    }
    if (data.containsKey('char_length')) {
      context.handle(
        _charLengthMeta,
        charLength.isAcceptableOrUnknown(data['char_length']!, _charLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_charLengthMeta);
    }
    if (data.containsKey('content_text')) {
      context.handle(
        _contentTextMeta,
        contentText.isAcceptableOrUnknown(
          data['content_text']!,
          _contentTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTextMeta);
    }
    if (data.containsKey('token_estimate')) {
      context.handle(
        _tokenEstimateMeta,
        tokenEstimate.isAcceptableOrUnknown(
          data['token_estimate']!,
          _tokenEstimateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tokenEstimateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookPassage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookPassage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      charOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_offset'],
      )!,
      charLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_length'],
      )!,
      contentText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_text'],
      )!,
      tokenEstimate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}token_estimate'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookPassagesTable createAlias(String alias) {
    return $BookPassagesTable(attachedDatabase, alias);
  }
}

class BookPassage extends DataClass implements Insertable<BookPassage> {
  final int id;
  final String bookId;
  final int chapterIndex;
  final int charOffset;
  final int charLength;
  final String contentText;
  final int tokenEstimate;
  final DateTime createdAt;
  const BookPassage({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.charOffset,
    required this.charLength,
    required this.contentText,
    required this.tokenEstimate,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['char_offset'] = Variable<int>(charOffset);
    map['char_length'] = Variable<int>(charLength);
    map['content_text'] = Variable<String>(contentText);
    map['token_estimate'] = Variable<int>(tokenEstimate);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookPassagesCompanion toCompanion(bool nullToAbsent) {
    return BookPassagesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      charOffset: Value(charOffset),
      charLength: Value(charLength),
      contentText: Value(contentText),
      tokenEstimate: Value(tokenEstimate),
      createdAt: Value(createdAt),
    );
  }

  factory BookPassage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookPassage(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      charOffset: serializer.fromJson<int>(json['charOffset']),
      charLength: serializer.fromJson<int>(json['charLength']),
      contentText: serializer.fromJson<String>(json['contentText']),
      tokenEstimate: serializer.fromJson<int>(json['tokenEstimate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'charOffset': serializer.toJson<int>(charOffset),
      'charLength': serializer.toJson<int>(charLength),
      'contentText': serializer.toJson<String>(contentText),
      'tokenEstimate': serializer.toJson<int>(tokenEstimate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookPassage copyWith({
    int? id,
    String? bookId,
    int? chapterIndex,
    int? charOffset,
    int? charLength,
    String? contentText,
    int? tokenEstimate,
    DateTime? createdAt,
  }) => BookPassage(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    charOffset: charOffset ?? this.charOffset,
    charLength: charLength ?? this.charLength,
    contentText: contentText ?? this.contentText,
    tokenEstimate: tokenEstimate ?? this.tokenEstimate,
    createdAt: createdAt ?? this.createdAt,
  );
  BookPassage copyWithCompanion(BookPassagesCompanion data) {
    return BookPassage(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      charOffset: data.charOffset.present
          ? data.charOffset.value
          : this.charOffset,
      charLength: data.charLength.present
          ? data.charLength.value
          : this.charLength,
      contentText: data.contentText.present
          ? data.contentText.value
          : this.contentText,
      tokenEstimate: data.tokenEstimate.present
          ? data.tokenEstimate.value
          : this.tokenEstimate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookPassage(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('charOffset: $charOffset, ')
          ..write('charLength: $charLength, ')
          ..write('contentText: $contentText, ')
          ..write('tokenEstimate: $tokenEstimate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    charOffset,
    charLength,
    contentText,
    tokenEstimate,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookPassage &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.charOffset == this.charOffset &&
          other.charLength == this.charLength &&
          other.contentText == this.contentText &&
          other.tokenEstimate == this.tokenEstimate &&
          other.createdAt == this.createdAt);
}

class BookPassagesCompanion extends UpdateCompanion<BookPassage> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> charOffset;
  final Value<int> charLength;
  final Value<String> contentText;
  final Value<int> tokenEstimate;
  final Value<DateTime> createdAt;
  const BookPassagesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.charLength = const Value.absent(),
    this.contentText = const Value.absent(),
    this.tokenEstimate = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookPassagesCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required int chapterIndex,
    required int charOffset,
    required int charLength,
    required String contentText,
    required int tokenEstimate,
    this.createdAt = const Value.absent(),
  }) : bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       charOffset = Value(charOffset),
       charLength = Value(charLength),
       contentText = Value(contentText),
       tokenEstimate = Value(tokenEstimate);
  static Insertable<BookPassage> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? charOffset,
    Expression<int>? charLength,
    Expression<String>? contentText,
    Expression<int>? tokenEstimate,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (charOffset != null) 'char_offset': charOffset,
      if (charLength != null) 'char_length': charLength,
      if (contentText != null) 'content_text': contentText,
      if (tokenEstimate != null) 'token_estimate': tokenEstimate,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookPassagesCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<int>? charOffset,
    Value<int>? charLength,
    Value<String>? contentText,
    Value<int>? tokenEstimate,
    Value<DateTime>? createdAt,
  }) {
    return BookPassagesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      charOffset: charOffset ?? this.charOffset,
      charLength: charLength ?? this.charLength,
      contentText: contentText ?? this.contentText,
      tokenEstimate: tokenEstimate ?? this.tokenEstimate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (charOffset.present) {
      map['char_offset'] = Variable<int>(charOffset.value);
    }
    if (charLength.present) {
      map['char_length'] = Variable<int>(charLength.value);
    }
    if (contentText.present) {
      map['content_text'] = Variable<String>(contentText.value);
    }
    if (tokenEstimate.present) {
      map['token_estimate'] = Variable<int>(tokenEstimate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookPassagesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('charOffset: $charOffset, ')
          ..write('charLength: $charLength, ')
          ..write('contentText: $contentText, ')
          ..write('tokenEstimate: $tokenEstimate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $QaHistoryTable extends QaHistory
    with TableInfo<$QaHistoryTable, QaHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QaHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _citationsJsonMeta = const VerificationMeta(
    'citationsJson',
  );
  @override
  late final GeneratedColumn<String> citationsJson = GeneratedColumn<String>(
    'citations_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    question,
    answer,
    citationsJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qa_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<QaHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('citations_json')) {
      context.handle(
        _citationsJsonMeta,
        citationsJson.isAcceptableOrUnknown(
          data['citations_json']!,
          _citationsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_citationsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QaHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QaHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      citationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}citations_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $QaHistoryTable createAlias(String alias) {
    return $QaHistoryTable(attachedDatabase, alias);
  }
}

class QaHistoryData extends DataClass implements Insertable<QaHistoryData> {
  final String id;
  final String bookId;
  final String question;
  final String answer;
  final String citationsJson;
  final DateTime createdAt;
  const QaHistoryData({
    required this.id,
    required this.bookId,
    required this.question,
    required this.answer,
    required this.citationsJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['question'] = Variable<String>(question);
    map['answer'] = Variable<String>(answer);
    map['citations_json'] = Variable<String>(citationsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QaHistoryCompanion toCompanion(bool nullToAbsent) {
    return QaHistoryCompanion(
      id: Value(id),
      bookId: Value(bookId),
      question: Value(question),
      answer: Value(answer),
      citationsJson: Value(citationsJson),
      createdAt: Value(createdAt),
    );
  }

  factory QaHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QaHistoryData(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      question: serializer.fromJson<String>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      citationsJson: serializer.fromJson<String>(json['citationsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'question': serializer.toJson<String>(question),
      'answer': serializer.toJson<String>(answer),
      'citationsJson': serializer.toJson<String>(citationsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  QaHistoryData copyWith({
    String? id,
    String? bookId,
    String? question,
    String? answer,
    String? citationsJson,
    DateTime? createdAt,
  }) => QaHistoryData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    citationsJson: citationsJson ?? this.citationsJson,
    createdAt: createdAt ?? this.createdAt,
  );
  QaHistoryData copyWithCompanion(QaHistoryCompanion data) {
    return QaHistoryData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      citationsJson: data.citationsJson.present
          ? data.citationsJson.value
          : this.citationsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QaHistoryData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('citationsJson: $citationsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, question, answer, citationsJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QaHistoryData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.citationsJson == this.citationsJson &&
          other.createdAt == this.createdAt);
}

class QaHistoryCompanion extends UpdateCompanion<QaHistoryData> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> question;
  final Value<String> answer;
  final Value<String> citationsJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const QaHistoryCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.citationsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QaHistoryCompanion.insert({
    required String id,
    required String bookId,
    required String question,
    required String answer,
    required String citationsJson,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       question = Value(question),
       answer = Value(answer),
       citationsJson = Value(citationsJson);
  static Insertable<QaHistoryData> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? question,
    Expression<String>? answer,
    Expression<String>? citationsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (citationsJson != null) 'citations_json': citationsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QaHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? question,
    Value<String>? answer,
    Value<String>? citationsJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return QaHistoryCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      citationsJson: citationsJson ?? this.citationsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (citationsJson.present) {
      map['citations_json'] = Variable<String>(citationsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QaHistoryCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('citationsJson: $citationsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, BookmarkEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _locatorJsonMeta = const VerificationMeta(
    'locatorJson',
  );
  @override
  late final GeneratedColumn<String> locatorJson = GeneratedColumn<String>(
    'locator_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    locatorJson,
    label,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('locator_json')) {
      context.handle(
        _locatorJsonMeta,
        locatorJson.isAcceptableOrUnknown(
          data['locator_json']!,
          _locatorJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locatorJsonMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarkEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      locatorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator_json'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class BookmarkEntry extends DataClass implements Insertable<BookmarkEntry> {
  final String id;
  final String bookId;
  final String locatorJson;
  final String label;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BookmarkEntry({
    required this.id,
    required this.bookId,
    required this.locatorJson,
    required this.label,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['locator_json'] = Variable<String>(locatorJson);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      locatorJson: Value(locatorJson),
      label: Value(label),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookmarkEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkEntry(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      locatorJson: serializer.fromJson<String>(json['locatorJson']),
      label: serializer.fromJson<String>(json['label']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'locatorJson': serializer.toJson<String>(locatorJson),
      'label': serializer.toJson<String>(label),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookmarkEntry copyWith({
    String? id,
    String? bookId,
    String? locatorJson,
    String? label,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookmarkEntry(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    locatorJson: locatorJson ?? this.locatorJson,
    label: label ?? this.label,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookmarkEntry copyWithCompanion(BookmarksCompanion data) {
    return BookmarkEntry(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      locatorJson: data.locatorJson.present
          ? data.locatorJson.value
          : this.locatorJson,
      label: data.label.present ? data.label.value : this.label,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkEntry(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('locatorJson: $locatorJson, ')
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, locatorJson, label, note, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkEntry &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.locatorJson == this.locatorJson &&
          other.label == this.label &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<BookmarkEntry> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> locatorJson;
  final Value<String> label;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.locatorJson = const Value.absent(),
    this.label = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String bookId,
    required String locatorJson,
    required String label,
    this.note = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       locatorJson = Value(locatorJson),
       label = Value(label),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookmarkEntry> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? locatorJson,
    Expression<String>? label,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (locatorJson != null) 'locator_json': locatorJson,
      if (label != null) 'label': label,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? locatorJson,
    Value<String>? label,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      locatorJson: locatorJson ?? this.locatorJson,
      label: label ?? this.label,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (locatorJson.present) {
      map['locator_json'] = Variable<String>(locatorJson.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('locatorJson: $locatorJson, ')
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $BookTagsTable bookTags = $BookTagsTable(this);
  late final $BookNotesTable bookNotes = $BookNotesTable(this);
  late final $AnnotationsTable annotations = $AnnotationsTable(this);
  late final $ReadingProgressTableTable readingProgressTable =
      $ReadingProgressTableTable(this);
  late final $TypographyProfilesTable typographyProfiles =
      $TypographyProfilesTable(this);
  late final $BookTypographyOverridesTable bookTypographyOverrides =
      $BookTypographyOverridesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $UserFontsTable userFonts = $UserFontsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $AiSummariesTable aiSummaries = $AiSummariesTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $BookPassagesTable bookPassages = $BookPassagesTable(this);
  late final $QaHistoryTable qaHistory = $QaHistoryTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final BooksDao booksDao = BooksDao(this as AppDatabase);
  late final BookTagsDao bookTagsDao = BookTagsDao(this as AppDatabase);
  late final BookNotesDao bookNotesDao = BookNotesDao(this as AppDatabase);
  late final AnnotationsDao annotationsDao = AnnotationsDao(
    this as AppDatabase,
  );
  late final ReadingProgressDao readingProgressDao = ReadingProgressDao(
    this as AppDatabase,
  );
  late final TypographyDao typographyDao = TypographyDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final UserFontsDao userFontsDao = UserFontsDao(this as AppDatabase);
  late final SyncOutboxDao syncOutboxDao = SyncOutboxDao(this as AppDatabase);
  late final AiSummariesDao aiSummariesDao = AiSummariesDao(
    this as AppDatabase,
  );
  late final SyncConflictsDao syncConflictsDao = SyncConflictsDao(
    this as AppDatabase,
  );
  late final BookPassagesDao bookPassagesDao = BookPassagesDao(
    this as AppDatabase,
  );
  late final QaHistoryDao qaHistoryDao = QaHistoryDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    bookTags,
    bookNotes,
    annotations,
    readingProgressTable,
    typographyProfiles,
    bookTypographyOverrides,
    settings,
    userFonts,
    syncOutbox,
    aiSummaries,
    syncConflicts,
    bookPassages,
    qaHistory,
    bookmarks,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String id,
      required String title,
      Value<String?> author,
      required String format,
      required String filePath,
      required String fileHash,
      required int fileSizeBytes,
      Value<String?> coverPath,
      Value<DateTime> addedAt,
      Value<DateTime?> lastReadAt,
      Value<int?> sortOrder,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> author,
      Value<String> format,
      Value<String> filePath,
      Value<String> fileHash,
      Value<int> fileSizeBytes,
      Value<String?> coverPath,
      Value<DateTime> addedAt,
      Value<DateTime?> lastReadAt,
      Value<int?> sortOrder,
      Value<int> rowid,
    });

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, Book> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BookNotesTable, List<BookNote>>
  _bookNotesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookNotes,
    aliasName: $_aliasNameGenerator(db.books.id, db.bookNotes.bookId),
  );

  $$BookNotesTableProcessedTableManager get bookNotesRefs {
    final manager = $$BookNotesTableTableManager(
      $_db,
      $_db.bookNotes,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookNotesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ReadingProgressTableTable,
    List<ReadingProgressTableData>
  >
  _readingProgressTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.readingProgressTable,
        aliasName: $_aliasNameGenerator(
          db.books.id,
          db.readingProgressTable.bookId,
        ),
      );

  $$ReadingProgressTableTableProcessedTableManager
  get readingProgressTableRefs {
    final manager = $$ReadingProgressTableTableTableManager(
      $_db,
      $_db.readingProgressTable,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingProgressTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $BookTypographyOverridesTable,
    List<BookTypographyOverride>
  >
  _bookTypographyOverridesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.bookTypographyOverrides,
        aliasName: $_aliasNameGenerator(
          db.books.id,
          db.bookTypographyOverrides.bookId,
        ),
      );

  $$BookTypographyOverridesTableProcessedTableManager
  get bookTypographyOverridesRefs {
    final manager = $$BookTypographyOverridesTableTableManager(
      $_db,
      $_db.bookTypographyOverrides,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bookTypographyOverridesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AiSummariesTable, List<AiSummary>>
  _aiSummariesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.aiSummaries,
    aliasName: $_aliasNameGenerator(db.books.id, db.aiSummaries.bookId),
  );

  $$AiSummariesTableProcessedTableManager get aiSummariesRefs {
    final manager = $$AiSummariesTableTableManager(
      $_db,
      $_db.aiSummaries,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_aiSummariesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<BookmarkEntry>>
  _bookmarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: $_aliasNameGenerator(db.books.id, db.bookmarks.bookId),
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bookNotesRefs(
    Expression<bool> Function($$BookNotesTableFilterComposer f) f,
  ) {
    final $$BookNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookNotes,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookNotesTableFilterComposer(
            $db: $db,
            $table: $db.bookNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingProgressTableRefs(
    Expression<bool> Function($$ReadingProgressTableTableFilterComposer f) f,
  ) {
    final $$ReadingProgressTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgressTable,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressTableTableFilterComposer(
            $db: $db,
            $table: $db.readingProgressTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookTypographyOverridesRefs(
    Expression<bool> Function($$BookTypographyOverridesTableFilterComposer f) f,
  ) {
    final $$BookTypographyOverridesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.bookTypographyOverrides,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BookTypographyOverridesTableFilterComposer(
                $db: $db,
                $table: $db.bookTypographyOverrides,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> aiSummariesRefs(
    Expression<bool> Function($$AiSummariesTableFilterComposer f) f,
  ) {
    final $$AiSummariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiSummaries,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiSummariesTableFilterComposer(
            $db: $db,
            $table: $db.aiSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> bookNotesRefs<T extends Object>(
    Expression<T> Function($$BookNotesTableAnnotationComposer a) f,
  ) {
    final $$BookNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookNotes,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingProgressTableRefs<T extends Object>(
    Expression<T> Function($$ReadingProgressTableTableAnnotationComposer a) f,
  ) {
    final $$ReadingProgressTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.readingProgressTable,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ReadingProgressTableTableAnnotationComposer(
                $db: $db,
                $table: $db.readingProgressTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> bookTypographyOverridesRefs<T extends Object>(
    Expression<T> Function($$BookTypographyOverridesTableAnnotationComposer a)
    f,
  ) {
    final $$BookTypographyOverridesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.bookTypographyOverrides,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BookTypographyOverridesTableAnnotationComposer(
                $db: $db,
                $table: $db.bookTypographyOverrides,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> aiSummariesRefs<T extends Object>(
    Expression<T> Function($$AiSummariesTableAnnotationComposer a) f,
  ) {
    final $$AiSummariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiSummaries,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiSummariesTableAnnotationComposer(
            $db: $db,
            $table: $db.aiSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, $$BooksTableReferences),
          Book,
          PrefetchHooks Function({
            bool bookNotesRefs,
            bool readingProgressTableRefs,
            bool bookTypographyOverridesRefs,
            bool aiSummariesRefs,
            bool bookmarksRefs,
          })
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> fileHash = const Value.absent(),
                Value<int> fileSizeBytes = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                author: author,
                format: format,
                filePath: filePath,
                fileHash: fileHash,
                fileSizeBytes: fileSizeBytes,
                coverPath: coverPath,
                addedAt: addedAt,
                lastReadAt: lastReadAt,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> author = const Value.absent(),
                required String format,
                required String filePath,
                required String fileHash,
                required int fileSizeBytes,
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                author: author,
                format: format,
                filePath: filePath,
                fileHash: fileHash,
                fileSizeBytes: fileSizeBytes,
                coverPath: coverPath,
                addedAt: addedAt,
                lastReadAt: lastReadAt,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BooksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                bookNotesRefs = false,
                readingProgressTableRefs = false,
                bookTypographyOverridesRefs = false,
                aiSummariesRefs = false,
                bookmarksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bookNotesRefs) db.bookNotes,
                    if (readingProgressTableRefs) db.readingProgressTable,
                    if (bookTypographyOverridesRefs) db.bookTypographyOverrides,
                    if (aiSummariesRefs) db.aiSummaries,
                    if (bookmarksRefs) db.bookmarks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bookNotesRefs)
                        await $_getPrefetchedData<Book, $BooksTable, BookNote>(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._bookNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookNotesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingProgressTableRefs)
                        await $_getPrefetchedData<
                          Book,
                          $BooksTable,
                          ReadingProgressTableData
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._readingProgressTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).readingProgressTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookTypographyOverridesRefs)
                        await $_getPrefetchedData<
                          Book,
                          $BooksTable,
                          BookTypographyOverride
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._bookTypographyOverridesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookTypographyOverridesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (aiSummariesRefs)
                        await $_getPrefetchedData<Book, $BooksTable, AiSummary>(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._aiSummariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).aiSummariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<
                          Book,
                          $BooksTable,
                          BookmarkEntry
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, $$BooksTableReferences),
      Book,
      PrefetchHooks Function({
        bool bookNotesRefs,
        bool readingProgressTableRefs,
        bool bookTypographyOverridesRefs,
        bool aiSummariesRefs,
        bool bookmarksRefs,
      })
    >;
typedef $$BookTagsTableCreateCompanionBuilder =
    BookTagsCompanion Function({
      required String bookId,
      required String tag,
      Value<int> rowid,
    });
typedef $$BookTagsTableUpdateCompanionBuilder =
    BookTagsCompanion Function({
      Value<String> bookId,
      Value<String> tag,
      Value<int> rowid,
    });

class $$BookTagsTableFilterComposer
    extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);
}

class $$BookTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookTagsTable,
          BookTag,
          $$BookTagsTableFilterComposer,
          $$BookTagsTableOrderingComposer,
          $$BookTagsTableAnnotationComposer,
          $$BookTagsTableCreateCompanionBuilder,
          $$BookTagsTableUpdateCompanionBuilder,
          (BookTag, BaseReferences<_$AppDatabase, $BookTagsTable, BookTag>),
          BookTag,
          PrefetchHooks Function()
        > {
  $$BookTagsTableTableManager(_$AppDatabase db, $BookTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookTagsCompanion(bookId: bookId, tag: tag, rowid: rowid),
          createCompanionCallback:
              ({
                required String bookId,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => BookTagsCompanion.insert(
                bookId: bookId,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookTagsTable,
      BookTag,
      $$BookTagsTableFilterComposer,
      $$BookTagsTableOrderingComposer,
      $$BookTagsTableAnnotationComposer,
      $$BookTagsTableCreateCompanionBuilder,
      $$BookTagsTableUpdateCompanionBuilder,
      (BookTag, BaseReferences<_$AppDatabase, $BookTagsTable, BookTag>),
      BookTag,
      PrefetchHooks Function()
    >;
typedef $$BookNotesTableCreateCompanionBuilder =
    BookNotesCompanion Function({
      required String id,
      required String bookId,
      required String title,
      Value<String> summary,
      Value<String> keyTakeaways,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$BookNotesTableUpdateCompanionBuilder =
    BookNotesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> title,
      Value<String> summary,
      Value<String> keyTakeaways,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$BookNotesTableReferences
    extends BaseReferences<_$AppDatabase, $BookNotesTable, BookNote> {
  $$BookNotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.bookNotes.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AnnotationsTable, List<Annotation>>
  _annotationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.annotations,
    aliasName: $_aliasNameGenerator(db.bookNotes.id, db.annotations.bookNoteId),
  );

  $$AnnotationsTableProcessedTableManager get annotationsRefs {
    final manager = $$AnnotationsTableTableManager(
      $_db,
      $_db.annotations,
    ).filter((f) => f.bookNoteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_annotationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BookNotesTableFilterComposer
    extends Composer<_$AppDatabase, $BookNotesTable> {
  $$BookNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyTakeaways => $composableBuilder(
    column: $table.keyTakeaways,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> annotationsRefs(
    Expression<bool> Function($$AnnotationsTableFilterComposer f) f,
  ) {
    final $$AnnotationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.annotations,
      getReferencedColumn: (t) => t.bookNoteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnnotationsTableFilterComposer(
            $db: $db,
            $table: $db.annotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BookNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookNotesTable> {
  $$BookNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyTakeaways => $composableBuilder(
    column: $table.keyTakeaways,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookNotesTable> {
  $$BookNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get keyTakeaways => $composableBuilder(
    column: $table.keyTakeaways,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> annotationsRefs<T extends Object>(
    Expression<T> Function($$AnnotationsTableAnnotationComposer a) f,
  ) {
    final $$AnnotationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.annotations,
      getReferencedColumn: (t) => t.bookNoteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnnotationsTableAnnotationComposer(
            $db: $db,
            $table: $db.annotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BookNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookNotesTable,
          BookNote,
          $$BookNotesTableFilterComposer,
          $$BookNotesTableOrderingComposer,
          $$BookNotesTableAnnotationComposer,
          $$BookNotesTableCreateCompanionBuilder,
          $$BookNotesTableUpdateCompanionBuilder,
          (BookNote, $$BookNotesTableReferences),
          BookNote,
          PrefetchHooks Function({bool bookId, bool annotationsRefs})
        > {
  $$BookNotesTableTableManager(_$AppDatabase db, $BookNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> keyTakeaways = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookNotesCompanion(
                id: id,
                bookId: bookId,
                title: title,
                summary: summary,
                keyTakeaways: keyTakeaways,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String title,
                Value<String> summary = const Value.absent(),
                Value<String> keyTakeaways = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookNotesCompanion.insert(
                id: id,
                bookId: bookId,
                title: title,
                summary: summary,
                keyTakeaways: keyTakeaways,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookNotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false, annotationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (annotationsRefs) db.annotations],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable: $$BookNotesTableReferences
                                    ._bookIdTable(db),
                                referencedColumn: $$BookNotesTableReferences
                                    ._bookIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (annotationsRefs)
                    await $_getPrefetchedData<
                      BookNote,
                      $BookNotesTable,
                      Annotation
                    >(
                      currentTable: table,
                      referencedTable: $$BookNotesTableReferences
                          ._annotationsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BookNotesTableReferences(
                            db,
                            table,
                            p0,
                          ).annotationsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.bookNoteId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BookNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookNotesTable,
      BookNote,
      $$BookNotesTableFilterComposer,
      $$BookNotesTableOrderingComposer,
      $$BookNotesTableAnnotationComposer,
      $$BookNotesTableCreateCompanionBuilder,
      $$BookNotesTableUpdateCompanionBuilder,
      (BookNote, $$BookNotesTableReferences),
      BookNote,
      PrefetchHooks Function({bool bookId, bool annotationsRefs})
    >;
typedef $$AnnotationsTableCreateCompanionBuilder =
    AnnotationsCompanion Function({
      required String id,
      required String bookNoteId,
      required String locator,
      required String quote,
      Value<String?> note,
      required String color,
      Value<String> tags,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AnnotationsTableUpdateCompanionBuilder =
    AnnotationsCompanion Function({
      Value<String> id,
      Value<String> bookNoteId,
      Value<String> locator,
      Value<String> quote,
      Value<String?> note,
      Value<String> color,
      Value<String> tags,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$AnnotationsTableReferences
    extends BaseReferences<_$AppDatabase, $AnnotationsTable, Annotation> {
  $$AnnotationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BookNotesTable _bookNoteIdTable(_$AppDatabase db) =>
      db.bookNotes.createAlias(
        $_aliasNameGenerator(db.annotations.bookNoteId, db.bookNotes.id),
      );

  $$BookNotesTableProcessedTableManager get bookNoteId {
    final $_column = $_itemColumn<String>('book_note_id')!;

    final manager = $$BookNotesTableTableManager(
      $_db,
      $_db.bookNotes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookNoteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AnnotationsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quote => $composableBuilder(
    column: $table.quote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BookNotesTableFilterComposer get bookNoteId {
    final $$BookNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookNoteId,
      referencedTable: $db.bookNotes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookNotesTableFilterComposer(
            $db: $db,
            $table: $db.bookNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quote => $composableBuilder(
    column: $table.quote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BookNotesTableOrderingComposer get bookNoteId {
    final $$BookNotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookNoteId,
      referencedTable: $db.bookNotes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookNotesTableOrderingComposer(
            $db: $db,
            $table: $db.bookNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get quote =>
      $composableBuilder(column: $table.quote, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BookNotesTableAnnotationComposer get bookNoteId {
    final $$BookNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookNoteId,
      referencedTable: $db.bookNotes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnnotationsTable,
          Annotation,
          $$AnnotationsTableFilterComposer,
          $$AnnotationsTableOrderingComposer,
          $$AnnotationsTableAnnotationComposer,
          $$AnnotationsTableCreateCompanionBuilder,
          $$AnnotationsTableUpdateCompanionBuilder,
          (Annotation, $$AnnotationsTableReferences),
          Annotation,
          PrefetchHooks Function({bool bookNoteId})
        > {
  $$AnnotationsTableTableManager(_$AppDatabase db, $AnnotationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookNoteId = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<String> quote = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnnotationsCompanion(
                id: id,
                bookNoteId: bookNoteId,
                locator: locator,
                quote: quote,
                note: note,
                color: color,
                tags: tags,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookNoteId,
                required String locator,
                required String quote,
                Value<String?> note = const Value.absent(),
                required String color,
                Value<String> tags = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnnotationsCompanion.insert(
                id: id,
                bookNoteId: bookNoteId,
                locator: locator,
                quote: quote,
                note: note,
                color: color,
                tags: tags,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AnnotationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookNoteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookNoteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookNoteId,
                                referencedTable: $$AnnotationsTableReferences
                                    ._bookNoteIdTable(db),
                                referencedColumn: $$AnnotationsTableReferences
                                    ._bookNoteIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnnotationsTable,
      Annotation,
      $$AnnotationsTableFilterComposer,
      $$AnnotationsTableOrderingComposer,
      $$AnnotationsTableAnnotationComposer,
      $$AnnotationsTableCreateCompanionBuilder,
      $$AnnotationsTableUpdateCompanionBuilder,
      (Annotation, $$AnnotationsTableReferences),
      Annotation,
      PrefetchHooks Function({bool bookNoteId})
    >;
typedef $$ReadingProgressTableTableCreateCompanionBuilder =
    ReadingProgressTableCompanion Function({
      required String bookId,
      required String locator,
      required double percent,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableTableUpdateCompanionBuilder =
    ReadingProgressTableCompanion Function({
      Value<String> bookId,
      Value<String> locator,
      Value<double> percent,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ReadingProgressTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTableTable,
          ReadingProgressTableData
        > {
  $$ReadingProgressTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.readingProgressTable.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<double> get percent =>
      $composableBuilder(column: $table.percent, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTableTable,
          ReadingProgressTableData,
          $$ReadingProgressTableTableFilterComposer,
          $$ReadingProgressTableTableOrderingComposer,
          $$ReadingProgressTableTableAnnotationComposer,
          $$ReadingProgressTableTableCreateCompanionBuilder,
          $$ReadingProgressTableTableUpdateCompanionBuilder,
          (ReadingProgressTableData, $$ReadingProgressTableTableReferences),
          ReadingProgressTableData,
          PrefetchHooks Function({bool bookId})
        > {
  $$ReadingProgressTableTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<double> percent = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressTableCompanion(
                bookId: bookId,
                locator: locator,
                percent: percent,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String locator,
                required double percent,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressTableCompanion.insert(
                bookId: bookId,
                locator: locator,
                percent: percent,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingProgressTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable:
                                    $$ReadingProgressTableTableReferences
                                        ._bookIdTable(db),
                                referencedColumn:
                                    $$ReadingProgressTableTableReferences
                                        ._bookIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingProgressTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTableTable,
      ReadingProgressTableData,
      $$ReadingProgressTableTableFilterComposer,
      $$ReadingProgressTableTableOrderingComposer,
      $$ReadingProgressTableTableAnnotationComposer,
      $$ReadingProgressTableTableCreateCompanionBuilder,
      $$ReadingProgressTableTableUpdateCompanionBuilder,
      (ReadingProgressTableData, $$ReadingProgressTableTableReferences),
      ReadingProgressTableData,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$TypographyProfilesTableCreateCompanionBuilder =
    TypographyProfilesCompanion Function({
      required String id,
      required String name,
      required String settings,
      Value<bool> isDefault,
      Value<int> rowid,
    });
typedef $$TypographyProfilesTableUpdateCompanionBuilder =
    TypographyProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> settings,
      Value<bool> isDefault,
      Value<int> rowid,
    });

class $$TypographyProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $TypographyProfilesTable> {
  $$TypographyProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settings => $composableBuilder(
    column: $table.settings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TypographyProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $TypographyProfilesTable> {
  $$TypographyProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settings => $composableBuilder(
    column: $table.settings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TypographyProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TypographyProfilesTable> {
  $$TypographyProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get settings =>
      $composableBuilder(column: $table.settings, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$TypographyProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TypographyProfilesTable,
          TypographyProfile,
          $$TypographyProfilesTableFilterComposer,
          $$TypographyProfilesTableOrderingComposer,
          $$TypographyProfilesTableAnnotationComposer,
          $$TypographyProfilesTableCreateCompanionBuilder,
          $$TypographyProfilesTableUpdateCompanionBuilder,
          (
            TypographyProfile,
            BaseReferences<
              _$AppDatabase,
              $TypographyProfilesTable,
              TypographyProfile
            >,
          ),
          TypographyProfile,
          PrefetchHooks Function()
        > {
  $$TypographyProfilesTableTableManager(
    _$AppDatabase db,
    $TypographyProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TypographyProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TypographyProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TypographyProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> settings = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TypographyProfilesCompanion(
                id: id,
                name: name,
                settings: settings,
                isDefault: isDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String settings,
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TypographyProfilesCompanion.insert(
                id: id,
                name: name,
                settings: settings,
                isDefault: isDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TypographyProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TypographyProfilesTable,
      TypographyProfile,
      $$TypographyProfilesTableFilterComposer,
      $$TypographyProfilesTableOrderingComposer,
      $$TypographyProfilesTableAnnotationComposer,
      $$TypographyProfilesTableCreateCompanionBuilder,
      $$TypographyProfilesTableUpdateCompanionBuilder,
      (
        TypographyProfile,
        BaseReferences<
          _$AppDatabase,
          $TypographyProfilesTable,
          TypographyProfile
        >,
      ),
      TypographyProfile,
      PrefetchHooks Function()
    >;
typedef $$BookTypographyOverridesTableCreateCompanionBuilder =
    BookTypographyOverridesCompanion Function({
      required String bookId,
      Value<String?> profileId,
      Value<String?> customSettings,
      Value<int> rowid,
    });
typedef $$BookTypographyOverridesTableUpdateCompanionBuilder =
    BookTypographyOverridesCompanion Function({
      Value<String> bookId,
      Value<String?> profileId,
      Value<String?> customSettings,
      Value<int> rowid,
    });

final class $$BookTypographyOverridesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $BookTypographyOverridesTable,
          BookTypographyOverride
        > {
  $$BookTypographyOverridesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.bookTypographyOverrides.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookTypographyOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $BookTypographyOverridesTable> {
  $$BookTypographyOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customSettings => $composableBuilder(
    column: $table.customSettings,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookTypographyOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookTypographyOverridesTable> {
  $$BookTypographyOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customSettings => $composableBuilder(
    column: $table.customSettings,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookTypographyOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookTypographyOverridesTable> {
  $$BookTypographyOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get customSettings => $composableBuilder(
    column: $table.customSettings,
    builder: (column) => column,
  );

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookTypographyOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookTypographyOverridesTable,
          BookTypographyOverride,
          $$BookTypographyOverridesTableFilterComposer,
          $$BookTypographyOverridesTableOrderingComposer,
          $$BookTypographyOverridesTableAnnotationComposer,
          $$BookTypographyOverridesTableCreateCompanionBuilder,
          $$BookTypographyOverridesTableUpdateCompanionBuilder,
          (BookTypographyOverride, $$BookTypographyOverridesTableReferences),
          BookTypographyOverride,
          PrefetchHooks Function({bool bookId})
        > {
  $$BookTypographyOverridesTableTableManager(
    _$AppDatabase db,
    $BookTypographyOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookTypographyOverridesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$BookTypographyOverridesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BookTypographyOverridesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String?> customSettings = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookTypographyOverridesCompanion(
                bookId: bookId,
                profileId: profileId,
                customSettings: customSettings,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                Value<String?> profileId = const Value.absent(),
                Value<String?> customSettings = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookTypographyOverridesCompanion.insert(
                bookId: bookId,
                profileId: profileId,
                customSettings: customSettings,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookTypographyOverridesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable:
                                    $$BookTypographyOverridesTableReferences
                                        ._bookIdTable(db),
                                referencedColumn:
                                    $$BookTypographyOverridesTableReferences
                                        ._bookIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookTypographyOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookTypographyOverridesTable,
      BookTypographyOverride,
      $$BookTypographyOverridesTableFilterComposer,
      $$BookTypographyOverridesTableOrderingComposer,
      $$BookTypographyOverridesTableAnnotationComposer,
      $$BookTypographyOverridesTableCreateCompanionBuilder,
      $$BookTypographyOverridesTableUpdateCompanionBuilder,
      (BookTypographyOverride, $$BookTypographyOverridesTableReferences),
      BookTypographyOverride,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$UserFontsTableCreateCompanionBuilder =
    UserFontsCompanion Function({
      required String id,
      required String displayName,
      required String fileName,
      required String familyName,
      required String hashSha1,
      required String absolutePath,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$UserFontsTableUpdateCompanionBuilder =
    UserFontsCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> fileName,
      Value<String> familyName,
      Value<String> hashSha1,
      Value<String> absolutePath,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$UserFontsTableFilterComposer
    extends Composer<_$AppDatabase, $UserFontsTable> {
  $$UserFontsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyName => $composableBuilder(
    column: $table.familyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hashSha1 => $composableBuilder(
    column: $table.hashSha1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get absolutePath => $composableBuilder(
    column: $table.absolutePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserFontsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserFontsTable> {
  $$UserFontsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyName => $composableBuilder(
    column: $table.familyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hashSha1 => $composableBuilder(
    column: $table.hashSha1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get absolutePath => $composableBuilder(
    column: $table.absolutePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserFontsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserFontsTable> {
  $$UserFontsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get familyName => $composableBuilder(
    column: $table.familyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hashSha1 =>
      $composableBuilder(column: $table.hashSha1, builder: (column) => column);

  GeneratedColumn<String> get absolutePath => $composableBuilder(
    column: $table.absolutePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$UserFontsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserFontsTable,
          UserFont,
          $$UserFontsTableFilterComposer,
          $$UserFontsTableOrderingComposer,
          $$UserFontsTableAnnotationComposer,
          $$UserFontsTableCreateCompanionBuilder,
          $$UserFontsTableUpdateCompanionBuilder,
          (UserFont, BaseReferences<_$AppDatabase, $UserFontsTable, UserFont>),
          UserFont,
          PrefetchHooks Function()
        > {
  $$UserFontsTableTableManager(_$AppDatabase db, $UserFontsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserFontsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserFontsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserFontsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> familyName = const Value.absent(),
                Value<String> hashSha1 = const Value.absent(),
                Value<String> absolutePath = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserFontsCompanion(
                id: id,
                displayName: displayName,
                fileName: fileName,
                familyName: familyName,
                hashSha1: hashSha1,
                absolutePath: absolutePath,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String fileName,
                required String familyName,
                required String hashSha1,
                required String absolutePath,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserFontsCompanion.insert(
                id: id,
                displayName: displayName,
                fileName: fileName,
                familyName: familyName,
                hashSha1: hashSha1,
                absolutePath: absolutePath,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserFontsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserFontsTable,
      UserFont,
      $$UserFontsTableFilterComposer,
      $$UserFontsTableOrderingComposer,
      $$UserFontsTableAnnotationComposer,
      $$UserFontsTableCreateCompanionBuilder,
      $$UserFontsTableUpdateCompanionBuilder,
      (UserFont, BaseReferences<_$AppDatabase, $UserFontsTable, UserFont>),
      UserFont,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<int> id,
      required String recordId,
      required String recordType,
      required String payloadJson,
      Value<DateTime> queuedAt,
      Value<DateTime?> pushedAt,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<int> id,
      Value<String> recordId,
      Value<String> recordType,
      Value<String> payloadJson,
      Value<DateTime> queuedAt,
      Value<DateTime?> pushedAt,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pushedAt => $composableBuilder(
    column: $table.pushedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pushedAt => $composableBuilder(
    column: $table.pushedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get pushedAt =>
      $composableBuilder(column: $table.pushedAt, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxData,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxData,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
          ),
          SyncOutboxData,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> recordType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<DateTime?> pushedAt = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                recordId: recordId,
                recordType: recordType,
                payloadJson: payloadJson,
                queuedAt: queuedAt,
                pushedAt: pushedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordId,
                required String recordType,
                required String payloadJson,
                Value<DateTime> queuedAt = const Value.absent(),
                Value<DateTime?> pushedAt = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                id: id,
                recordId: recordId,
                recordType: recordType,
                payloadJson: payloadJson,
                queuedAt: queuedAt,
                pushedAt: pushedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxData,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxData,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
      ),
      SyncOutboxData,
      PrefetchHooks Function()
    >;
typedef $$AiSummariesTableCreateCompanionBuilder =
    AiSummariesCompanion Function({
      Value<int> id,
      required String bookId,
      required String mode,
      required String sourceHash,
      required String summaryText,
      required String modelName,
      required String baseUrl,
      Value<DateTime> generatedAt,
      required int promptVersion,
    });
typedef $$AiSummariesTableUpdateCompanionBuilder =
    AiSummariesCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<String> mode,
      Value<String> sourceHash,
      Value<String> summaryText,
      Value<String> modelName,
      Value<String> baseUrl,
      Value<DateTime> generatedAt,
      Value<int> promptVersion,
    });

final class $$AiSummariesTableReferences
    extends BaseReferences<_$AppDatabase, $AiSummariesTable, AiSummary> {
  $$AiSummariesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.aiSummaries.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AiSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $AiSummariesTable> {
  $$AiSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $AiSummariesTable> {
  $$AiSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiSummariesTable> {
  $$AiSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => column,
  );

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiSummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiSummariesTable,
          AiSummary,
          $$AiSummariesTableFilterComposer,
          $$AiSummariesTableOrderingComposer,
          $$AiSummariesTableAnnotationComposer,
          $$AiSummariesTableCreateCompanionBuilder,
          $$AiSummariesTableUpdateCompanionBuilder,
          (AiSummary, $$AiSummariesTableReferences),
          AiSummary,
          PrefetchHooks Function({bool bookId})
        > {
  $$AiSummariesTableTableManager(_$AppDatabase db, $AiSummariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> sourceHash = const Value.absent(),
                Value<String> summaryText = const Value.absent(),
                Value<String> modelName = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<int> promptVersion = const Value.absent(),
              }) => AiSummariesCompanion(
                id: id,
                bookId: bookId,
                mode: mode,
                sourceHash: sourceHash,
                summaryText: summaryText,
                modelName: modelName,
                baseUrl: baseUrl,
                generatedAt: generatedAt,
                promptVersion: promptVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required String mode,
                required String sourceHash,
                required String summaryText,
                required String modelName,
                required String baseUrl,
                Value<DateTime> generatedAt = const Value.absent(),
                required int promptVersion,
              }) => AiSummariesCompanion.insert(
                id: id,
                bookId: bookId,
                mode: mode,
                sourceHash: sourceHash,
                summaryText: summaryText,
                modelName: modelName,
                baseUrl: baseUrl,
                generatedAt: generatedAt,
                promptVersion: promptVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AiSummariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable: $$AiSummariesTableReferences
                                    ._bookIdTable(db),
                                referencedColumn: $$AiSummariesTableReferences
                                    ._bookIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AiSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiSummariesTable,
      AiSummary,
      $$AiSummariesTableFilterComposer,
      $$AiSummariesTableOrderingComposer,
      $$AiSummariesTableAnnotationComposer,
      $$AiSummariesTableCreateCompanionBuilder,
      $$AiSummariesTableUpdateCompanionBuilder,
      (AiSummary, $$AiSummariesTableReferences),
      AiSummary,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      required String recordId,
      required String recordType,
      required DateTime localMtime,
      required DateTime remoteMtime,
      required String winnerDevice,
      required String loserDevice,
      required DateTime detectedAt,
      required String payloadPreview,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      Value<String> recordId,
      Value<String> recordType,
      Value<DateTime> localMtime,
      Value<DateTime> remoteMtime,
      Value<String> winnerDevice,
      Value<String> loserDevice,
      Value<DateTime> detectedAt,
      Value<String> payloadPreview,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localMtime => $composableBuilder(
    column: $table.localMtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteMtime => $composableBuilder(
    column: $table.remoteMtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get winnerDevice => $composableBuilder(
    column: $table.winnerDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loserDevice => $composableBuilder(
    column: $table.loserDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadPreview => $composableBuilder(
    column: $table.payloadPreview,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localMtime => $composableBuilder(
    column: $table.localMtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteMtime => $composableBuilder(
    column: $table.remoteMtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winnerDevice => $composableBuilder(
    column: $table.winnerDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loserDevice => $composableBuilder(
    column: $table.loserDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadPreview => $composableBuilder(
    column: $table.payloadPreview,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localMtime => $composableBuilder(
    column: $table.localMtime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get remoteMtime => $composableBuilder(
    column: $table.remoteMtime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get winnerDevice => $composableBuilder(
    column: $table.winnerDevice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loserDevice => $composableBuilder(
    column: $table.loserDevice,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadPreview => $composableBuilder(
    column: $table.payloadPreview,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflict,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflict,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
          ),
          SyncConflict,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> recordType = const Value.absent(),
                Value<DateTime> localMtime = const Value.absent(),
                Value<DateTime> remoteMtime = const Value.absent(),
                Value<String> winnerDevice = const Value.absent(),
                Value<String> loserDevice = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<String> payloadPreview = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                recordId: recordId,
                recordType: recordType,
                localMtime: localMtime,
                remoteMtime: remoteMtime,
                winnerDevice: winnerDevice,
                loserDevice: loserDevice,
                detectedAt: detectedAt,
                payloadPreview: payloadPreview,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordId,
                required String recordType,
                required DateTime localMtime,
                required DateTime remoteMtime,
                required String winnerDevice,
                required String loserDevice,
                required DateTime detectedAt,
                required String payloadPreview,
              }) => SyncConflictsCompanion.insert(
                id: id,
                recordId: recordId,
                recordType: recordType,
                localMtime: localMtime,
                remoteMtime: remoteMtime,
                winnerDevice: winnerDevice,
                loserDevice: loserDevice,
                detectedAt: detectedAt,
                payloadPreview: payloadPreview,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflict,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflict,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
      ),
      SyncConflict,
      PrefetchHooks Function()
    >;
typedef $$BookPassagesTableCreateCompanionBuilder =
    BookPassagesCompanion Function({
      Value<int> id,
      required String bookId,
      required int chapterIndex,
      required int charOffset,
      required int charLength,
      required String contentText,
      required int tokenEstimate,
      Value<DateTime> createdAt,
    });
typedef $$BookPassagesTableUpdateCompanionBuilder =
    BookPassagesCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<int> charOffset,
      Value<int> charLength,
      Value<String> contentText,
      Value<int> tokenEstimate,
      Value<DateTime> createdAt,
    });

class $$BookPassagesTableFilterComposer
    extends Composer<_$AppDatabase, $BookPassagesTable> {
  $$BookPassagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charLength => $composableBuilder(
    column: $table.charLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokenEstimate => $composableBuilder(
    column: $table.tokenEstimate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookPassagesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookPassagesTable> {
  $$BookPassagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charLength => $composableBuilder(
    column: $table.charLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokenEstimate => $composableBuilder(
    column: $table.tokenEstimate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookPassagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookPassagesTable> {
  $$BookPassagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charLength => $composableBuilder(
    column: $table.charLength,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tokenEstimate => $composableBuilder(
    column: $table.tokenEstimate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookPassagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookPassagesTable,
          BookPassage,
          $$BookPassagesTableFilterComposer,
          $$BookPassagesTableOrderingComposer,
          $$BookPassagesTableAnnotationComposer,
          $$BookPassagesTableCreateCompanionBuilder,
          $$BookPassagesTableUpdateCompanionBuilder,
          (
            BookPassage,
            BaseReferences<_$AppDatabase, $BookPassagesTable, BookPassage>,
          ),
          BookPassage,
          PrefetchHooks Function()
        > {
  $$BookPassagesTableTableManager(_$AppDatabase db, $BookPassagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookPassagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookPassagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookPassagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> charOffset = const Value.absent(),
                Value<int> charLength = const Value.absent(),
                Value<String> contentText = const Value.absent(),
                Value<int> tokenEstimate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookPassagesCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                charOffset: charOffset,
                charLength: charLength,
                contentText: contentText,
                tokenEstimate: tokenEstimate,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required int chapterIndex,
                required int charOffset,
                required int charLength,
                required String contentText,
                required int tokenEstimate,
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookPassagesCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                charOffset: charOffset,
                charLength: charLength,
                contentText: contentText,
                tokenEstimate: tokenEstimate,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookPassagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookPassagesTable,
      BookPassage,
      $$BookPassagesTableFilterComposer,
      $$BookPassagesTableOrderingComposer,
      $$BookPassagesTableAnnotationComposer,
      $$BookPassagesTableCreateCompanionBuilder,
      $$BookPassagesTableUpdateCompanionBuilder,
      (
        BookPassage,
        BaseReferences<_$AppDatabase, $BookPassagesTable, BookPassage>,
      ),
      BookPassage,
      PrefetchHooks Function()
    >;
typedef $$QaHistoryTableCreateCompanionBuilder =
    QaHistoryCompanion Function({
      required String id,
      required String bookId,
      required String question,
      required String answer,
      required String citationsJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$QaHistoryTableUpdateCompanionBuilder =
    QaHistoryCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> question,
      Value<String> answer,
      Value<String> citationsJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$QaHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $QaHistoryTable> {
  $$QaHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get citationsJson => $composableBuilder(
    column: $table.citationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QaHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $QaHistoryTable> {
  $$QaHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get citationsJson => $composableBuilder(
    column: $table.citationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QaHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $QaHistoryTable> {
  $$QaHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get citationsJson => $composableBuilder(
    column: $table.citationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QaHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QaHistoryTable,
          QaHistoryData,
          $$QaHistoryTableFilterComposer,
          $$QaHistoryTableOrderingComposer,
          $$QaHistoryTableAnnotationComposer,
          $$QaHistoryTableCreateCompanionBuilder,
          $$QaHistoryTableUpdateCompanionBuilder,
          (
            QaHistoryData,
            BaseReferences<_$AppDatabase, $QaHistoryTable, QaHistoryData>,
          ),
          QaHistoryData,
          PrefetchHooks Function()
        > {
  $$QaHistoryTableTableManager(_$AppDatabase db, $QaHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QaHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QaHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QaHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> citationsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QaHistoryCompanion(
                id: id,
                bookId: bookId,
                question: question,
                answer: answer,
                citationsJson: citationsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String question,
                required String answer,
                required String citationsJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QaHistoryCompanion.insert(
                id: id,
                bookId: bookId,
                question: question,
                answer: answer,
                citationsJson: citationsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QaHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QaHistoryTable,
      QaHistoryData,
      $$QaHistoryTableFilterComposer,
      $$QaHistoryTableOrderingComposer,
      $$QaHistoryTableAnnotationComposer,
      $$QaHistoryTableCreateCompanionBuilder,
      $$QaHistoryTableUpdateCompanionBuilder,
      (
        QaHistoryData,
        BaseReferences<_$AppDatabase, $QaHistoryTable, QaHistoryData>,
      ),
      QaHistoryData,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required String bookId,
      required String locatorJson,
      required String label,
      Value<String?> note,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> locatorJson,
      Value<String> label,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$BookmarksTableReferences
    extends BaseReferences<_$AppDatabase, $BookmarksTable, BookmarkEntry> {
  $$BookmarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.bookmarks.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locatorJson => $composableBuilder(
    column: $table.locatorJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locatorJson => $composableBuilder(
    column: $table.locatorJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locatorJson => $composableBuilder(
    column: $table.locatorJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          BookmarkEntry,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (BookmarkEntry, $$BookmarksTableReferences),
          BookmarkEntry,
          PrefetchHooks Function({bool bookId})
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> locatorJson = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookId: bookId,
                locatorJson: locatorJson,
                label: label,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String locatorJson,
                required String label,
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                locatorJson: locatorJson,
                label: label,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookmarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable: $$BookmarksTableReferences
                                    ._bookIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._bookIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      BookmarkEntry,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (BookmarkEntry, $$BookmarksTableReferences),
      BookmarkEntry,
      PrefetchHooks Function({bool bookId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$BookTagsTableTableManager get bookTags =>
      $$BookTagsTableTableManager(_db, _db.bookTags);
  $$BookNotesTableTableManager get bookNotes =>
      $$BookNotesTableTableManager(_db, _db.bookNotes);
  $$AnnotationsTableTableManager get annotations =>
      $$AnnotationsTableTableManager(_db, _db.annotations);
  $$ReadingProgressTableTableTableManager get readingProgressTable =>
      $$ReadingProgressTableTableTableManager(_db, _db.readingProgressTable);
  $$TypographyProfilesTableTableManager get typographyProfiles =>
      $$TypographyProfilesTableTableManager(_db, _db.typographyProfiles);
  $$BookTypographyOverridesTableTableManager get bookTypographyOverrides =>
      $$BookTypographyOverridesTableTableManager(
        _db,
        _db.bookTypographyOverrides,
      );
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$UserFontsTableTableManager get userFonts =>
      $$UserFontsTableTableManager(_db, _db.userFonts);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$AiSummariesTableTableManager get aiSummaries =>
      $$AiSummariesTableTableManager(_db, _db.aiSummaries);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$BookPassagesTableTableManager get bookPassages =>
      $$BookPassagesTableTableManager(_db, _db.bookPassages);
  $$QaHistoryTableTableManager get qaHistory =>
      $$QaHistoryTableTableManager(_db, _db.qaHistory);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
}
