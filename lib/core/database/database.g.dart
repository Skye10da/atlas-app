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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
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
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('book'),
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalChaptersMeta = const VerificationMeta(
    'totalChapters',
  );
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
    'total_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
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
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    coverPath,
    description,
    format,
    filePath,
    itemType,
    fileSize,
    totalChapters,
    language,
    tags,
    sourceName,
    sourceId,
    sourceUrl,
    rating,
    status,
    createdAt,
    updatedAt,
    lastOpenedAt,
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
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
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
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
        _totalChaptersMeta,
        totalChapters.isAcceptableOrUnknown(
          data['total_chapters']!,
          _totalChaptersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalChaptersMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
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
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      totalChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapters'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
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
  final String? coverPath;
  final String? description;
  final String format;
  final String filePath;
  final String itemType;
  final int? fileSize;
  final int totalChapters;
  final String? language;
  final String? tags;
  final String? sourceName;
  final String? sourceId;
  final String? sourceUrl;
  final double? rating;
  final String? status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  const Book({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
    this.description,
    required this.format,
    required this.filePath,
    required this.itemType,
    this.fileSize,
    required this.totalChapters,
    this.language,
    this.tags,
    this.sourceName,
    this.sourceId,
    this.sourceUrl,
    this.rating,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['format'] = Variable<String>(format);
    map['file_path'] = Variable<String>(filePath);
    map['item_type'] = Variable<String>(itemType);
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    map['total_chapters'] = Variable<int>(totalChapters);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || sourceName != null) {
      map['source_name'] = Variable<String>(sourceName);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
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
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      format: Value(format),
      filePath: Value(filePath),
      itemType: Value(itemType),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      totalChapters: Value(totalChapters),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      sourceName: sourceName == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceName),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
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
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      description: serializer.fromJson<String?>(json['description']),
      format: serializer.fromJson<String>(json['format']),
      filePath: serializer.fromJson<String>(json['filePath']),
      itemType: serializer.fromJson<String>(json['itemType']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      totalChapters: serializer.fromJson<int>(json['totalChapters']),
      language: serializer.fromJson<String?>(json['language']),
      tags: serializer.fromJson<String?>(json['tags']),
      sourceName: serializer.fromJson<String?>(json['sourceName']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      rating: serializer.fromJson<double?>(json['rating']),
      status: serializer.fromJson<String?>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'coverPath': serializer.toJson<String?>(coverPath),
      'description': serializer.toJson<String?>(description),
      'format': serializer.toJson<String>(format),
      'filePath': serializer.toJson<String>(filePath),
      'itemType': serializer.toJson<String>(itemType),
      'fileSize': serializer.toJson<int?>(fileSize),
      'totalChapters': serializer.toJson<int>(totalChapters),
      'language': serializer.toJson<String?>(language),
      'tags': serializer.toJson<String?>(tags),
      'sourceName': serializer.toJson<String?>(sourceName),
      'sourceId': serializer.toJson<String?>(sourceId),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'rating': serializer.toJson<double?>(rating),
      'status': serializer.toJson<String?>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
    };
  }

  Book copyWith({
    String? id,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> description = const Value.absent(),
    String? format,
    String? filePath,
    String? itemType,
    Value<int?> fileSize = const Value.absent(),
    int? totalChapters,
    Value<String?> language = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> sourceName = const Value.absent(),
    Value<String?> sourceId = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<String?> status = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    description: description.present ? description.value : this.description,
    format: format ?? this.format,
    filePath: filePath ?? this.filePath,
    itemType: itemType ?? this.itemType,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    totalChapters: totalChapters ?? this.totalChapters,
    language: language.present ? language.value : this.language,
    tags: tags.present ? tags.value : this.tags,
    sourceName: sourceName.present ? sourceName.value : this.sourceName,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    rating: rating.present ? rating.value : this.rating,
    status: status.present ? status.value : this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      description: data.description.present
          ? data.description.value
          : this.description,
      format: data.format.present ? data.format.value : this.format,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      language: data.language.present ? data.language.value : this.language,
      tags: data.tags.present ? data.tags.value : this.tags,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      rating: data.rating.present ? data.rating.value : this.rating,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('description: $description, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('itemType: $itemType, ')
          ..write('fileSize: $fileSize, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('language: $language, ')
          ..write('tags: $tags, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('rating: $rating, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    coverPath,
    description,
    format,
    filePath,
    itemType,
    fileSize,
    totalChapters,
    language,
    tags,
    sourceName,
    sourceId,
    sourceUrl,
    rating,
    status,
    createdAt,
    updatedAt,
    lastOpenedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverPath == this.coverPath &&
          other.description == this.description &&
          other.format == this.format &&
          other.filePath == this.filePath &&
          other.itemType == this.itemType &&
          other.fileSize == this.fileSize &&
          other.totalChapters == this.totalChapters &&
          other.language == this.language &&
          other.tags == this.tags &&
          other.sourceName == this.sourceName &&
          other.sourceId == this.sourceId &&
          other.sourceUrl == this.sourceUrl &&
          other.rating == this.rating &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> coverPath;
  final Value<String?> description;
  final Value<String> format;
  final Value<String> filePath;
  final Value<String> itemType;
  final Value<int?> fileSize;
  final Value<int> totalChapters;
  final Value<String?> language;
  final Value<String?> tags;
  final Value<String?> sourceName;
  final Value<String?> sourceId;
  final Value<String?> sourceUrl;
  final Value<double?> rating;
  final Value<String?> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.description = const Value.absent(),
    this.format = const Value.absent(),
    this.filePath = const Value.absent(),
    this.itemType = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.language = const Value.absent(),
    this.tags = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.description = const Value.absent(),
    required String format,
    required String filePath,
    this.itemType = const Value.absent(),
    this.fileSize = const Value.absent(),
    required int totalChapters,
    this.language = const Value.absent(),
    this.tags = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       format = Value(format),
       filePath = Value(filePath),
       totalChapters = Value(totalChapters),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Book> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverPath,
    Expression<String>? description,
    Expression<String>? format,
    Expression<String>? filePath,
    Expression<String>? itemType,
    Expression<int>? fileSize,
    Expression<int>? totalChapters,
    Expression<String>? language,
    Expression<String>? tags,
    Expression<String>? sourceName,
    Expression<String>? sourceId,
    Expression<String>? sourceUrl,
    Expression<double>? rating,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverPath != null) 'cover_path': coverPath,
      if (description != null) 'description': description,
      if (format != null) 'format': format,
      if (filePath != null) 'file_path': filePath,
      if (itemType != null) 'item_type': itemType,
      if (fileSize != null) 'file_size': fileSize,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (language != null) 'language': language,
      if (tags != null) 'tags': tags,
      if (sourceName != null) 'source_name': sourceName,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (rating != null) 'rating': rating,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? coverPath,
    Value<String?>? description,
    Value<String>? format,
    Value<String>? filePath,
    Value<String>? itemType,
    Value<int?>? fileSize,
    Value<int>? totalChapters,
    Value<String?>? language,
    Value<String?>? tags,
    Value<String?>? sourceName,
    Value<String?>? sourceId,
    Value<String?>? sourceUrl,
    Value<double?>? rating,
    Value<String?>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      description: description ?? this.description,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      itemType: itemType ?? this.itemType,
      fileSize: fileSize ?? this.fileSize,
      totalChapters: totalChapters ?? this.totalChapters,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      sourceName: sourceName ?? this.sourceName,
      sourceId: sourceId ?? this.sourceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
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
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
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
          ..write('coverPath: $coverPath, ')
          ..write('description: $description, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('itemType: $itemType, ')
          ..write('fileSize: $fileSize, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('language: $language, ')
          ..write('tags: $tags, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('rating: $rating, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _indexMeta = const VerificationMeta('index');
  @override
  late final GeneratedColumn<int> index = GeneratedColumn<int>(
    'index',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _contentPathMeta = const VerificationMeta(
    'contentPath',
  );
  @override
  late final GeneratedColumn<String> contentPath = GeneratedColumn<String>(
    'content_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentStateMeta = const VerificationMeta(
    'contentState',
  );
  @override
  late final GeneratedColumn<int> contentState = GeneratedColumn<int>(
    'content_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previousVersionRefMeta =
      const VerificationMeta('previousVersionRef');
  @override
  late final GeneratedColumn<String> previousVersionRef =
      GeneratedColumn<String>(
        'previous_version_ref',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    index,
    title,
    contentPath,
    wordCount,
    contentState,
    pageCount,
    createdAt,
    version,
    checksum,
    previousVersionRef,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
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
    if (data.containsKey('index')) {
      context.handle(
        _indexMeta,
        index.isAcceptableOrUnknown(data['index']!, _indexMeta),
      );
    } else if (isInserting) {
      context.missing(_indexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content_path')) {
      context.handle(
        _contentPathMeta,
        contentPath.isAcceptableOrUnknown(
          data['content_path']!,
          _contentPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentPathMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    } else if (isInserting) {
      context.missing(_wordCountMeta);
    }
    if (data.containsKey('content_state')) {
      context.handle(
        _contentStateMeta,
        contentState.isAcceptableOrUnknown(
          data['content_state']!,
          _contentStateMeta,
        ),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    }
    if (data.containsKey('previous_version_ref')) {
      context.handle(
        _previousVersionRefMeta,
        previousVersionRef.isAcceptableOrUnknown(
          data['previous_version_ref']!,
          _previousVersionRefMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      index: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      contentPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_path'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      contentState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_state'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      ),
      previousVersionRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_version_ref'],
      ),
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final String id;
  final String bookId;
  final int index;
  final String title;
  final String contentPath;
  final int wordCount;
  final int contentState;
  final int pageCount;
  final DateTime createdAt;

  /// Content versioning (CDA v2.2): bumped whenever the chapter's content
  /// changes after a re-fetch.
  final int version;

  /// sha256(content) of the currently stored content.
  final String? checksum;

  /// Id of the previous content version, if this chapter has been re-fetched.
  final String? previousVersionRef;
  const Chapter({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    required this.contentPath,
    required this.wordCount,
    required this.contentState,
    required this.pageCount,
    required this.createdAt,
    required this.version,
    this.checksum,
    this.previousVersionRef,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['index'] = Variable<int>(index);
    map['title'] = Variable<String>(title);
    map['content_path'] = Variable<String>(contentPath);
    map['word_count'] = Variable<int>(wordCount);
    map['content_state'] = Variable<int>(contentState);
    map['page_count'] = Variable<int>(pageCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    if (!nullToAbsent || previousVersionRef != null) {
      map['previous_version_ref'] = Variable<String>(previousVersionRef);
    }
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      bookId: Value(bookId),
      index: Value(index),
      title: Value(title),
      contentPath: Value(contentPath),
      wordCount: Value(wordCount),
      contentState: Value(contentState),
      pageCount: Value(pageCount),
      createdAt: Value(createdAt),
      version: Value(version),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      previousVersionRef: previousVersionRef == null && nullToAbsent
          ? const Value.absent()
          : Value(previousVersionRef),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      index: serializer.fromJson<int>(json['index']),
      title: serializer.fromJson<String>(json['title']),
      contentPath: serializer.fromJson<String>(json['contentPath']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      contentState: serializer.fromJson<int>(json['contentState']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      version: serializer.fromJson<int>(json['version']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      previousVersionRef: serializer.fromJson<String?>(
        json['previousVersionRef'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'index': serializer.toJson<int>(index),
      'title': serializer.toJson<String>(title),
      'contentPath': serializer.toJson<String>(contentPath),
      'wordCount': serializer.toJson<int>(wordCount),
      'contentState': serializer.toJson<int>(contentState),
      'pageCount': serializer.toJson<int>(pageCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'version': serializer.toJson<int>(version),
      'checksum': serializer.toJson<String?>(checksum),
      'previousVersionRef': serializer.toJson<String?>(previousVersionRef),
    };
  }

  Chapter copyWith({
    String? id,
    String? bookId,
    int? index,
    String? title,
    String? contentPath,
    int? wordCount,
    int? contentState,
    int? pageCount,
    DateTime? createdAt,
    int? version,
    Value<String?> checksum = const Value.absent(),
    Value<String?> previousVersionRef = const Value.absent(),
  }) => Chapter(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    index: index ?? this.index,
    title: title ?? this.title,
    contentPath: contentPath ?? this.contentPath,
    wordCount: wordCount ?? this.wordCount,
    contentState: contentState ?? this.contentState,
    pageCount: pageCount ?? this.pageCount,
    createdAt: createdAt ?? this.createdAt,
    version: version ?? this.version,
    checksum: checksum.present ? checksum.value : this.checksum,
    previousVersionRef: previousVersionRef.present
        ? previousVersionRef.value
        : this.previousVersionRef,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      index: data.index.present ? data.index.value : this.index,
      title: data.title.present ? data.title.value : this.title,
      contentPath: data.contentPath.present
          ? data.contentPath.value
          : this.contentPath,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      contentState: data.contentState.present
          ? data.contentState.value
          : this.contentState,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      version: data.version.present ? data.version.value : this.version,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      previousVersionRef: data.previousVersionRef.present
          ? data.previousVersionRef.value
          : this.previousVersionRef,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('index: $index, ')
          ..write('title: $title, ')
          ..write('contentPath: $contentPath, ')
          ..write('wordCount: $wordCount, ')
          ..write('contentState: $contentState, ')
          ..write('pageCount: $pageCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('version: $version, ')
          ..write('checksum: $checksum, ')
          ..write('previousVersionRef: $previousVersionRef')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    index,
    title,
    contentPath,
    wordCount,
    contentState,
    pageCount,
    createdAt,
    version,
    checksum,
    previousVersionRef,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.index == this.index &&
          other.title == this.title &&
          other.contentPath == this.contentPath &&
          other.wordCount == this.wordCount &&
          other.contentState == this.contentState &&
          other.pageCount == this.pageCount &&
          other.createdAt == this.createdAt &&
          other.version == this.version &&
          other.checksum == this.checksum &&
          other.previousVersionRef == this.previousVersionRef);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> index;
  final Value<String> title;
  final Value<String> contentPath;
  final Value<int> wordCount;
  final Value<int> contentState;
  final Value<int> pageCount;
  final Value<DateTime> createdAt;
  final Value<int> version;
  final Value<String?> checksum;
  final Value<String?> previousVersionRef;
  final Value<int> rowid;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.index = const Value.absent(),
    this.title = const Value.absent(),
    this.contentPath = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.contentState = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.version = const Value.absent(),
    this.checksum = const Value.absent(),
    this.previousVersionRef = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChaptersCompanion.insert({
    required String id,
    required String bookId,
    required int index,
    required String title,
    required String contentPath,
    required int wordCount,
    this.contentState = const Value.absent(),
    required int pageCount,
    required DateTime createdAt,
    this.version = const Value.absent(),
    this.checksum = const Value.absent(),
    this.previousVersionRef = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       index = Value(index),
       title = Value(title),
       contentPath = Value(contentPath),
       wordCount = Value(wordCount),
       pageCount = Value(pageCount),
       createdAt = Value(createdAt);
  static Insertable<Chapter> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? index,
    Expression<String>? title,
    Expression<String>? contentPath,
    Expression<int>? wordCount,
    Expression<int>? contentState,
    Expression<int>? pageCount,
    Expression<DateTime>? createdAt,
    Expression<int>? version,
    Expression<String>? checksum,
    Expression<String>? previousVersionRef,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (index != null) 'index': index,
      if (title != null) 'title': title,
      if (contentPath != null) 'content_path': contentPath,
      if (wordCount != null) 'word_count': wordCount,
      if (contentState != null) 'content_state': contentState,
      if (pageCount != null) 'page_count': pageCount,
      if (createdAt != null) 'created_at': createdAt,
      if (version != null) 'version': version,
      if (checksum != null) 'checksum': checksum,
      if (previousVersionRef != null)
        'previous_version_ref': previousVersionRef,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChaptersCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? index,
    Value<String>? title,
    Value<String>? contentPath,
    Value<int>? wordCount,
    Value<int>? contentState,
    Value<int>? pageCount,
    Value<DateTime>? createdAt,
    Value<int>? version,
    Value<String?>? checksum,
    Value<String?>? previousVersionRef,
    Value<int>? rowid,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      index: index ?? this.index,
      title: title ?? this.title,
      contentPath: contentPath ?? this.contentPath,
      wordCount: wordCount ?? this.wordCount,
      contentState: contentState ?? this.contentState,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      checksum: checksum ?? this.checksum,
      previousVersionRef: previousVersionRef ?? this.previousVersionRef,
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
    if (index.present) {
      map['index'] = Variable<int>(index.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contentPath.present) {
      map['content_path'] = Variable<String>(contentPath.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (contentState.present) {
      map['content_state'] = Variable<int>(contentState.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (previousVersionRef.present) {
      map['previous_version_ref'] = Variable<String>(previousVersionRef.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('index: $index, ')
          ..write('title: $title, ')
          ..write('contentPath: $contentPath, ')
          ..write('wordCount: $wordCount, ')
          ..write('contentState: $contentState, ')
          ..write('pageCount: $pageCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('version: $version, ')
          ..write('checksum: $checksum, ')
          ..write('previousVersionRef: $previousVersionRef, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _percentageMeta = const VerificationMeta(
    'percentage',
  );
  @override
  late final GeneratedColumn<double> percentage = GeneratedColumn<double>(
    'percentage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPositionsMeta = const VerificationMeta(
    'totalPositions',
  );
  @override
  late final GeneratedColumn<int> totalPositions = GeneratedColumn<int>(
    'total_positions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingTimeSecondsMeta =
      const VerificationMeta('readingTimeSeconds');
  @override
  late final GeneratedColumn<int> readingTimeSeconds = GeneratedColumn<int>(
    'reading_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterId,
    percentage,
    position,
    totalPositions,
    lastReadAt,
    readingTimeSeconds,
    isCompleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressData> instance, {
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
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('percentage')) {
      context.handle(
        _percentageMeta,
        percentage.isAcceptableOrUnknown(data['percentage']!, _percentageMeta),
      );
    } else if (isInserting) {
      context.missing(_percentageMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('total_positions')) {
      context.handle(
        _totalPositionsMeta,
        totalPositions.isAcceptableOrUnknown(
          data['total_positions']!,
          _totalPositionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPositionsMeta);
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastReadAtMeta);
    }
    if (data.containsKey('reading_time_seconds')) {
      context.handle(
        _readingTimeSecondsMeta,
        readingTimeSeconds.isAcceptableOrUnknown(
          data['reading_time_seconds']!,
          _readingTimeSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_readingTimeSecondsMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      percentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percentage'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      totalPositions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_positions'],
      )!,
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      )!,
      readingTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reading_time_seconds'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressData extends DataClass
    implements Insertable<ReadingProgressData> {
  final String id;
  final String bookId;
  final String chapterId;
  final double percentage;
  final int position;
  final int totalPositions;
  final DateTime lastReadAt;
  final int readingTimeSeconds;
  final bool isCompleted;
  const ReadingProgressData({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.percentage,
    required this.position,
    required this.totalPositions,
    required this.lastReadAt,
    required this.readingTimeSeconds,
    required this.isCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<String>(chapterId);
    map['percentage'] = Variable<double>(percentage);
    map['position'] = Variable<int>(position);
    map['total_positions'] = Variable<int>(totalPositions);
    map['last_read_at'] = Variable<DateTime>(lastReadAt);
    map['reading_time_seconds'] = Variable<int>(readingTimeSeconds);
    map['is_completed'] = Variable<bool>(isCompleted);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      percentage: Value(percentage),
      position: Value(position),
      totalPositions: Value(totalPositions),
      lastReadAt: Value(lastReadAt),
      readingTimeSeconds: Value(readingTimeSeconds),
      isCompleted: Value(isCompleted),
    );
  }

  factory ReadingProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressData(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      percentage: serializer.fromJson<double>(json['percentage']),
      position: serializer.fromJson<int>(json['position']),
      totalPositions: serializer.fromJson<int>(json['totalPositions']),
      lastReadAt: serializer.fromJson<DateTime>(json['lastReadAt']),
      readingTimeSeconds: serializer.fromJson<int>(json['readingTimeSeconds']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterId': serializer.toJson<String>(chapterId),
      'percentage': serializer.toJson<double>(percentage),
      'position': serializer.toJson<int>(position),
      'totalPositions': serializer.toJson<int>(totalPositions),
      'lastReadAt': serializer.toJson<DateTime>(lastReadAt),
      'readingTimeSeconds': serializer.toJson<int>(readingTimeSeconds),
      'isCompleted': serializer.toJson<bool>(isCompleted),
    };
  }

  ReadingProgressData copyWith({
    String? id,
    String? bookId,
    String? chapterId,
    double? percentage,
    int? position,
    int? totalPositions,
    DateTime? lastReadAt,
    int? readingTimeSeconds,
    bool? isCompleted,
  }) => ReadingProgressData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    percentage: percentage ?? this.percentage,
    position: position ?? this.position,
    totalPositions: totalPositions ?? this.totalPositions,
    lastReadAt: lastReadAt ?? this.lastReadAt,
    readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
    isCompleted: isCompleted ?? this.isCompleted,
  );
  ReadingProgressData copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      percentage: data.percentage.present
          ? data.percentage.value
          : this.percentage,
      position: data.position.present ? data.position.value : this.position,
      totalPositions: data.totalPositions.present
          ? data.totalPositions.value
          : this.totalPositions,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      readingTimeSeconds: data.readingTimeSeconds.present
          ? data.readingTimeSeconds.value
          : this.readingTimeSeconds,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('percentage: $percentage, ')
          ..write('position: $position, ')
          ..write('totalPositions: $totalPositions, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('readingTimeSeconds: $readingTimeSeconds, ')
          ..write('isCompleted: $isCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterId,
    percentage,
    position,
    totalPositions,
    lastReadAt,
    readingTimeSeconds,
    isCompleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.percentage == this.percentage &&
          other.position == this.position &&
          other.totalPositions == this.totalPositions &&
          other.lastReadAt == this.lastReadAt &&
          other.readingTimeSeconds == this.readingTimeSeconds &&
          other.isCompleted == this.isCompleted);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressData> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> chapterId;
  final Value<double> percentage;
  final Value<int> position;
  final Value<int> totalPositions;
  final Value<DateTime> lastReadAt;
  final Value<int> readingTimeSeconds;
  final Value<bool> isCompleted;
  final Value<int> rowid;
  const ReadingProgressCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.percentage = const Value.absent(),
    this.position = const Value.absent(),
    this.totalPositions = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.readingTimeSeconds = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    required String id,
    required String bookId,
    required String chapterId,
    required double percentage,
    required int position,
    required int totalPositions,
    required DateTime lastReadAt,
    required int readingTimeSeconds,
    this.isCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterId = Value(chapterId),
       percentage = Value(percentage),
       position = Value(position),
       totalPositions = Value(totalPositions),
       lastReadAt = Value(lastReadAt),
       readingTimeSeconds = Value(readingTimeSeconds);
  static Insertable<ReadingProgressData> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? chapterId,
    Expression<double>? percentage,
    Expression<int>? position,
    Expression<int>? totalPositions,
    Expression<DateTime>? lastReadAt,
    Expression<int>? readingTimeSeconds,
    Expression<bool>? isCompleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (percentage != null) 'percentage': percentage,
      if (position != null) 'position': position,
      if (totalPositions != null) 'total_positions': totalPositions,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (readingTimeSeconds != null)
        'reading_time_seconds': readingTimeSeconds,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? chapterId,
    Value<double>? percentage,
    Value<int>? position,
    Value<int>? totalPositions,
    Value<DateTime>? lastReadAt,
    Value<int>? readingTimeSeconds,
    Value<bool>? isCompleted,
    Value<int>? rowid,
  }) {
    return ReadingProgressCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      percentage: percentage ?? this.percentage,
      position: position ?? this.position,
      totalPositions: totalPositions ?? this.totalPositions,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
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
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (percentage.present) {
      map['percentage'] = Variable<double>(percentage.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (totalPositions.present) {
      map['total_positions'] = Variable<int>(totalPositions.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (readingTimeSeconds.present) {
      map['reading_time_seconds'] = Variable<int>(readingTimeSeconds.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('percentage: $percentage, ')
          ..write('position: $position, ')
          ..write('totalPositions: $totalPositions, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('readingTimeSeconds: $readingTimeSeconds, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
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
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    chapterId,
    position,
    note,
    color,
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
    Insertable<Bookmark> instance, {
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
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
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
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
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

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final String id;
  final String bookId;
  final String chapterId;
  final int position;
  final String? note;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.position,
    this.note,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<String>(chapterId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      position: Value(position),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      position: serializer.fromJson<int>(json['position']),
      note: serializer.fromJson<String?>(json['note']),
      color: serializer.fromJson<String?>(json['color']),
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
      'chapterId': serializer.toJson<String>(chapterId),
      'position': serializer.toJson<int>(position),
      'note': serializer.toJson<String?>(note),
      'color': serializer.toJson<String?>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Bookmark copyWith({
    String? id,
    String? bookId,
    String? chapterId,
    int? position,
    Value<String?> note = const Value.absent(),
    Value<String?> color = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Bookmark(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    position: position ?? this.position,
    note: note.present ? note.value : this.note,
    color: color.present ? color.value : this.color,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      position: data.position.present ? data.position.value : this.position,
      note: data.note.present ? data.note.value : this.note,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('position: $position, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterId,
    position,
    note,
    color,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.position == this.position &&
          other.note == this.note &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> chapterId;
  final Value<int> position;
  final Value<String?> note;
  final Value<String?> color;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.position = const Value.absent(),
    this.note = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String bookId,
    required String chapterId,
    required int position,
    this.note = const Value.absent(),
    this.color = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterId = Value(chapterId),
       position = Value(position),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Bookmark> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? chapterId,
    Expression<int>? position,
    Expression<String>? note,
    Expression<String>? color,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (position != null) 'position': position,
      if (note != null) 'note': note,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? chapterId,
    Value<int>? position,
    Value<String?>? note,
    Value<String?>? color,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      position: position ?? this.position,
      note: note ?? this.note,
      color: color ?? this.color,
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
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
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
          ..write('chapterId: $chapterId, ')
          ..write('position: $position, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
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
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, Character> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasesMeta = const VerificationMeta(
    'aliases',
  );
  @override
  late final GeneratedColumn<String> aliases = GeneratedColumn<String>(
    'aliases',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstAppearanceMeta = const VerificationMeta(
    'firstAppearance',
  );
  @override
  late final GeneratedColumn<String> firstAppearance = GeneratedColumn<String>(
    'first_appearance',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
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
    name,
    aliases,
    description,
    role,
    firstAppearance,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Character> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('aliases')) {
      context.handle(
        _aliasesMeta,
        aliases.isAcceptableOrUnknown(data['aliases']!, _aliasesMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('first_appearance')) {
      context.handle(
        _firstAppearanceMeta,
        firstAppearance.isAcceptableOrUnknown(
          data['first_appearance']!,
          _firstAppearanceMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Character map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Character(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      aliases: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      firstAppearance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_appearance'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
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
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class Character extends DataClass implements Insertable<Character> {
  final String id;
  final String bookId;
  final String name;
  final String? aliases;
  final String? description;
  final String? role;
  final String? firstAppearance;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Character({
    required this.id,
    required this.bookId,
    required this.name,
    this.aliases,
    this.description,
    this.role,
    this.firstAppearance,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || aliases != null) {
      map['aliases'] = Variable<String>(aliases);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || firstAppearance != null) {
      map['first_appearance'] = Variable<String>(firstAppearance);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CharactersCompanion toCompanion(bool nullToAbsent) {
    return CharactersCompanion(
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      aliases: aliases == null && nullToAbsent
          ? const Value.absent()
          : Value(aliases),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      firstAppearance: firstAppearance == null && nullToAbsent
          ? const Value.absent()
          : Value(firstAppearance),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Character.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Character(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      aliases: serializer.fromJson<String?>(json['aliases']),
      description: serializer.fromJson<String?>(json['description']),
      role: serializer.fromJson<String?>(json['role']),
      firstAppearance: serializer.fromJson<String?>(json['firstAppearance']),
      notes: serializer.fromJson<String?>(json['notes']),
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
      'name': serializer.toJson<String>(name),
      'aliases': serializer.toJson<String?>(aliases),
      'description': serializer.toJson<String?>(description),
      'role': serializer.toJson<String?>(role),
      'firstAppearance': serializer.toJson<String?>(firstAppearance),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Character copyWith({
    String? id,
    String? bookId,
    String? name,
    Value<String?> aliases = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<String?> firstAppearance = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Character(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    name: name ?? this.name,
    aliases: aliases.present ? aliases.value : this.aliases,
    description: description.present ? description.value : this.description,
    role: role.present ? role.value : this.role,
    firstAppearance: firstAppearance.present
        ? firstAppearance.value
        : this.firstAppearance,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Character copyWithCompanion(CharactersCompanion data) {
    return Character(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      aliases: data.aliases.present ? data.aliases.value : this.aliases,
      description: data.description.present
          ? data.description.value
          : this.description,
      role: data.role.present ? data.role.value : this.role,
      firstAppearance: data.firstAppearance.present
          ? data.firstAppearance.value
          : this.firstAppearance,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Character(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('aliases: $aliases, ')
          ..write('description: $description, ')
          ..write('role: $role, ')
          ..write('firstAppearance: $firstAppearance, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    name,
    aliases,
    description,
    role,
    firstAppearance,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Character &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.aliases == this.aliases &&
          other.description == this.description &&
          other.role == this.role &&
          other.firstAppearance == this.firstAppearance &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CharactersCompanion extends UpdateCompanion<Character> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<String?> aliases;
  final Value<String?> description;
  final Value<String?> role;
  final Value<String?> firstAppearance;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CharactersCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.aliases = const Value.absent(),
    this.description = const Value.absent(),
    this.role = const Value.absent(),
    this.firstAppearance = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CharactersCompanion.insert({
    required String id,
    required String bookId,
    required String name,
    this.aliases = const Value.absent(),
    this.description = const Value.absent(),
    this.role = const Value.absent(),
    this.firstAppearance = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Character> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<String>? aliases,
    Expression<String>? description,
    Expression<String>? role,
    Expression<String>? firstAppearance,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (aliases != null) 'aliases': aliases,
      if (description != null) 'description': description,
      if (role != null) 'role': role,
      if (firstAppearance != null) 'first_appearance': firstAppearance,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CharactersCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? name,
    Value<String?>? aliases,
    Value<String?>? description,
    Value<String?>? role,
    Value<String?>? firstAppearance,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CharactersCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      description: description ?? this.description,
      role: role ?? this.role,
      firstAppearance: firstAppearance ?? this.firstAppearance,
      notes: notes ?? this.notes,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (aliases.present) {
      map['aliases'] = Variable<String>(aliases.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (firstAppearance.present) {
      map['first_appearance'] = Variable<String>(firstAppearance.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
    return (StringBuffer('CharactersCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('aliases: $aliases, ')
          ..write('description: $description, ')
          ..write('role: $role, ')
          ..write('firstAppearance: $firstAppearance, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DictionaryWordsTable extends DictionaryWords
    with TableInfo<$DictionaryWordsTable, DictionaryWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageLabelMeta = const VerificationMeta(
    'languageLabel',
  );
  @override
  late final GeneratedColumn<String> languageLabel = GeneratedColumn<String>(
    'language_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('wiktionary'),
  );
  static const VerificationMeta _sourceLabelMeta = const VerificationMeta(
    'sourceLabel',
  );
  @override
  late final GeneratedColumn<String> sourceLabel = GeneratedColumn<String>(
    'source_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Wiktionary'),
  );
  static const VerificationMeta _phoneticMeta = const VerificationMeta(
    'phonetic',
  );
  @override
  late final GeneratedColumn<String> phonetic = GeneratedColumn<String>(
    'phonetic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partOfSpeechMeta = const VerificationMeta(
    'partOfSpeech',
  );
  @override
  late final GeneratedColumn<String> partOfSpeech = GeneratedColumn<String>(
    'part_of_speech',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionMeta = const VerificationMeta(
    'definition',
  );
  @override
  late final GeneratedColumn<String> definition = GeneratedColumn<String>(
    'definition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullJsonMeta = const VerificationMeta(
    'fullJson',
  );
  @override
  late final GeneratedColumn<String> fullJson = GeneratedColumn<String>(
    'full_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSentenceMeta = const VerificationMeta(
    'sourceSentence',
  );
  @override
  late final GeneratedColumn<String> sourceSentence = GeneratedColumn<String>(
    'source_sentence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTitleMeta = const VerificationMeta(
    'sourceTitle',
  );
  @override
  late final GeneratedColumn<String> sourceTitle = GeneratedColumn<String>(
    'source_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewLevelMeta = const VerificationMeta(
    'reviewLevel',
  );
  @override
  late final GeneratedColumn<int> reviewLevel = GeneratedColumn<int>(
    'review_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reviewCountMeta = const VerificationMeta(
    'reviewCount',
  );
  @override
  late final GeneratedColumn<int> reviewCount = GeneratedColumn<int>(
    'review_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta(
    'lastReviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewedAt =
      GeneratedColumn<DateTime>(
        'last_reviewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextReviewAtMeta = const VerificationMeta(
    'nextReviewAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextReviewAt = GeneratedColumn<DateTime>(
    'next_review_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    word,
    language,
    languageLabel,
    source,
    sourceLabel,
    phonetic,
    partOfSpeech,
    definition,
    fullJson,
    savedAt,
    sourceSentence,
    sourceTitle,
    reviewLevel,
    reviewCount,
    lastReviewedAt,
    nextReviewAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_words';
  @override
  VerificationContext validateIntegrity(
    Insertable<DictionaryWord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('language_label')) {
      context.handle(
        _languageLabelMeta,
        languageLabel.isAcceptableOrUnknown(
          data['language_label']!,
          _languageLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_languageLabelMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('source_label')) {
      context.handle(
        _sourceLabelMeta,
        sourceLabel.isAcceptableOrUnknown(
          data['source_label']!,
          _sourceLabelMeta,
        ),
      );
    }
    if (data.containsKey('phonetic')) {
      context.handle(
        _phoneticMeta,
        phonetic.isAcceptableOrUnknown(data['phonetic']!, _phoneticMeta),
      );
    }
    if (data.containsKey('part_of_speech')) {
      context.handle(
        _partOfSpeechMeta,
        partOfSpeech.isAcceptableOrUnknown(
          data['part_of_speech']!,
          _partOfSpeechMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_partOfSpeechMeta);
    }
    if (data.containsKey('definition')) {
      context.handle(
        _definitionMeta,
        definition.isAcceptableOrUnknown(data['definition']!, _definitionMeta),
      );
    } else if (isInserting) {
      context.missing(_definitionMeta);
    }
    if (data.containsKey('full_json')) {
      context.handle(
        _fullJsonMeta,
        fullJson.isAcceptableOrUnknown(data['full_json']!, _fullJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_fullJsonMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    if (data.containsKey('source_sentence')) {
      context.handle(
        _sourceSentenceMeta,
        sourceSentence.isAcceptableOrUnknown(
          data['source_sentence']!,
          _sourceSentenceMeta,
        ),
      );
    }
    if (data.containsKey('source_title')) {
      context.handle(
        _sourceTitleMeta,
        sourceTitle.isAcceptableOrUnknown(
          data['source_title']!,
          _sourceTitleMeta,
        ),
      );
    }
    if (data.containsKey('review_level')) {
      context.handle(
        _reviewLevelMeta,
        reviewLevel.isAcceptableOrUnknown(
          data['review_level']!,
          _reviewLevelMeta,
        ),
      );
    }
    if (data.containsKey('review_count')) {
      context.handle(
        _reviewCountMeta,
        reviewCount.isAcceptableOrUnknown(
          data['review_count']!,
          _reviewCountMeta,
        ),
      );
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(
          data['last_reviewed_at']!,
          _lastReviewedAtMeta,
        ),
      );
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
        _nextReviewAtMeta,
        nextReviewAt.isAcceptableOrUnknown(
          data['next_review_at']!,
          _nextReviewAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DictionaryWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryWord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      languageLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_label'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_label'],
      )!,
      phonetic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phonetic'],
      ),
      partOfSpeech: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_of_speech'],
      )!,
      definition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition'],
      )!,
      fullJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_json'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
      sourceSentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_sentence'],
      ),
      sourceTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_title'],
      ),
      reviewLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_level'],
      )!,
      reviewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_count'],
      )!,
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed_at'],
      ),
      nextReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_review_at'],
      ),
    );
  }

  @override
  $DictionaryWordsTable createAlias(String alias) {
    return $DictionaryWordsTable(attachedDatabase, alias);
  }
}

class DictionaryWord extends DataClass implements Insertable<DictionaryWord> {
  final String id;
  final String word;
  final String language;
  final String languageLabel;
  final String source;
  final String sourceLabel;
  final String? phonetic;
  final String partOfSpeech;
  final String definition;
  final String fullJson;
  final DateTime savedAt;
  final String? sourceSentence;
  final String? sourceTitle;
  final int reviewLevel;
  final int reviewCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  const DictionaryWord({
    required this.id,
    required this.word,
    required this.language,
    required this.languageLabel,
    required this.source,
    required this.sourceLabel,
    this.phonetic,
    required this.partOfSpeech,
    required this.definition,
    required this.fullJson,
    required this.savedAt,
    this.sourceSentence,
    this.sourceTitle,
    required this.reviewLevel,
    required this.reviewCount,
    this.lastReviewedAt,
    this.nextReviewAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['word'] = Variable<String>(word);
    map['language'] = Variable<String>(language);
    map['language_label'] = Variable<String>(languageLabel);
    map['source'] = Variable<String>(source);
    map['source_label'] = Variable<String>(sourceLabel);
    if (!nullToAbsent || phonetic != null) {
      map['phonetic'] = Variable<String>(phonetic);
    }
    map['part_of_speech'] = Variable<String>(partOfSpeech);
    map['definition'] = Variable<String>(definition);
    map['full_json'] = Variable<String>(fullJson);
    map['saved_at'] = Variable<DateTime>(savedAt);
    if (!nullToAbsent || sourceSentence != null) {
      map['source_sentence'] = Variable<String>(sourceSentence);
    }
    if (!nullToAbsent || sourceTitle != null) {
      map['source_title'] = Variable<String>(sourceTitle);
    }
    map['review_level'] = Variable<int>(reviewLevel);
    map['review_count'] = Variable<int>(reviewCount);
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt);
    }
    if (!nullToAbsent || nextReviewAt != null) {
      map['next_review_at'] = Variable<DateTime>(nextReviewAt);
    }
    return map;
  }

  DictionaryWordsCompanion toCompanion(bool nullToAbsent) {
    return DictionaryWordsCompanion(
      id: Value(id),
      word: Value(word),
      language: Value(language),
      languageLabel: Value(languageLabel),
      source: Value(source),
      sourceLabel: Value(sourceLabel),
      phonetic: phonetic == null && nullToAbsent
          ? const Value.absent()
          : Value(phonetic),
      partOfSpeech: Value(partOfSpeech),
      definition: Value(definition),
      fullJson: Value(fullJson),
      savedAt: Value(savedAt),
      sourceSentence: sourceSentence == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSentence),
      sourceTitle: sourceTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTitle),
      reviewLevel: Value(reviewLevel),
      reviewCount: Value(reviewCount),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
      nextReviewAt: nextReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextReviewAt),
    );
  }

  factory DictionaryWord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryWord(
      id: serializer.fromJson<String>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      language: serializer.fromJson<String>(json['language']),
      languageLabel: serializer.fromJson<String>(json['languageLabel']),
      source: serializer.fromJson<String>(json['source']),
      sourceLabel: serializer.fromJson<String>(json['sourceLabel']),
      phonetic: serializer.fromJson<String?>(json['phonetic']),
      partOfSpeech: serializer.fromJson<String>(json['partOfSpeech']),
      definition: serializer.fromJson<String>(json['definition']),
      fullJson: serializer.fromJson<String>(json['fullJson']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
      sourceSentence: serializer.fromJson<String?>(json['sourceSentence']),
      sourceTitle: serializer.fromJson<String?>(json['sourceTitle']),
      reviewLevel: serializer.fromJson<int>(json['reviewLevel']),
      reviewCount: serializer.fromJson<int>(json['reviewCount']),
      lastReviewedAt: serializer.fromJson<DateTime?>(json['lastReviewedAt']),
      nextReviewAt: serializer.fromJson<DateTime?>(json['nextReviewAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'word': serializer.toJson<String>(word),
      'language': serializer.toJson<String>(language),
      'languageLabel': serializer.toJson<String>(languageLabel),
      'source': serializer.toJson<String>(source),
      'sourceLabel': serializer.toJson<String>(sourceLabel),
      'phonetic': serializer.toJson<String?>(phonetic),
      'partOfSpeech': serializer.toJson<String>(partOfSpeech),
      'definition': serializer.toJson<String>(definition),
      'fullJson': serializer.toJson<String>(fullJson),
      'savedAt': serializer.toJson<DateTime>(savedAt),
      'sourceSentence': serializer.toJson<String?>(sourceSentence),
      'sourceTitle': serializer.toJson<String?>(sourceTitle),
      'reviewLevel': serializer.toJson<int>(reviewLevel),
      'reviewCount': serializer.toJson<int>(reviewCount),
      'lastReviewedAt': serializer.toJson<DateTime?>(lastReviewedAt),
      'nextReviewAt': serializer.toJson<DateTime?>(nextReviewAt),
    };
  }

  DictionaryWord copyWith({
    String? id,
    String? word,
    String? language,
    String? languageLabel,
    String? source,
    String? sourceLabel,
    Value<String?> phonetic = const Value.absent(),
    String? partOfSpeech,
    String? definition,
    String? fullJson,
    DateTime? savedAt,
    Value<String?> sourceSentence = const Value.absent(),
    Value<String?> sourceTitle = const Value.absent(),
    int? reviewLevel,
    int? reviewCount,
    Value<DateTime?> lastReviewedAt = const Value.absent(),
    Value<DateTime?> nextReviewAt = const Value.absent(),
  }) => DictionaryWord(
    id: id ?? this.id,
    word: word ?? this.word,
    language: language ?? this.language,
    languageLabel: languageLabel ?? this.languageLabel,
    source: source ?? this.source,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    phonetic: phonetic.present ? phonetic.value : this.phonetic,
    partOfSpeech: partOfSpeech ?? this.partOfSpeech,
    definition: definition ?? this.definition,
    fullJson: fullJson ?? this.fullJson,
    savedAt: savedAt ?? this.savedAt,
    sourceSentence: sourceSentence.present
        ? sourceSentence.value
        : this.sourceSentence,
    sourceTitle: sourceTitle.present ? sourceTitle.value : this.sourceTitle,
    reviewLevel: reviewLevel ?? this.reviewLevel,
    reviewCount: reviewCount ?? this.reviewCount,
    lastReviewedAt: lastReviewedAt.present
        ? lastReviewedAt.value
        : this.lastReviewedAt,
    nextReviewAt: nextReviewAt.present ? nextReviewAt.value : this.nextReviewAt,
  );
  DictionaryWord copyWithCompanion(DictionaryWordsCompanion data) {
    return DictionaryWord(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      language: data.language.present ? data.language.value : this.language,
      languageLabel: data.languageLabel.present
          ? data.languageLabel.value
          : this.languageLabel,
      source: data.source.present ? data.source.value : this.source,
      sourceLabel: data.sourceLabel.present
          ? data.sourceLabel.value
          : this.sourceLabel,
      phonetic: data.phonetic.present ? data.phonetic.value : this.phonetic,
      partOfSpeech: data.partOfSpeech.present
          ? data.partOfSpeech.value
          : this.partOfSpeech,
      definition: data.definition.present
          ? data.definition.value
          : this.definition,
      fullJson: data.fullJson.present ? data.fullJson.value : this.fullJson,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
      sourceSentence: data.sourceSentence.present
          ? data.sourceSentence.value
          : this.sourceSentence,
      sourceTitle: data.sourceTitle.present
          ? data.sourceTitle.value
          : this.sourceTitle,
      reviewLevel: data.reviewLevel.present
          ? data.reviewLevel.value
          : this.reviewLevel,
      reviewCount: data.reviewCount.present
          ? data.reviewCount.value
          : this.reviewCount,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryWord(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('language: $language, ')
          ..write('languageLabel: $languageLabel, ')
          ..write('source: $source, ')
          ..write('sourceLabel: $sourceLabel, ')
          ..write('phonetic: $phonetic, ')
          ..write('partOfSpeech: $partOfSpeech, ')
          ..write('definition: $definition, ')
          ..write('fullJson: $fullJson, ')
          ..write('savedAt: $savedAt, ')
          ..write('sourceSentence: $sourceSentence, ')
          ..write('sourceTitle: $sourceTitle, ')
          ..write('reviewLevel: $reviewLevel, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('nextReviewAt: $nextReviewAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    word,
    language,
    languageLabel,
    source,
    sourceLabel,
    phonetic,
    partOfSpeech,
    definition,
    fullJson,
    savedAt,
    sourceSentence,
    sourceTitle,
    reviewLevel,
    reviewCount,
    lastReviewedAt,
    nextReviewAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryWord &&
          other.id == this.id &&
          other.word == this.word &&
          other.language == this.language &&
          other.languageLabel == this.languageLabel &&
          other.source == this.source &&
          other.sourceLabel == this.sourceLabel &&
          other.phonetic == this.phonetic &&
          other.partOfSpeech == this.partOfSpeech &&
          other.definition == this.definition &&
          other.fullJson == this.fullJson &&
          other.savedAt == this.savedAt &&
          other.sourceSentence == this.sourceSentence &&
          other.sourceTitle == this.sourceTitle &&
          other.reviewLevel == this.reviewLevel &&
          other.reviewCount == this.reviewCount &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.nextReviewAt == this.nextReviewAt);
}

class DictionaryWordsCompanion extends UpdateCompanion<DictionaryWord> {
  final Value<String> id;
  final Value<String> word;
  final Value<String> language;
  final Value<String> languageLabel;
  final Value<String> source;
  final Value<String> sourceLabel;
  final Value<String?> phonetic;
  final Value<String> partOfSpeech;
  final Value<String> definition;
  final Value<String> fullJson;
  final Value<DateTime> savedAt;
  final Value<String?> sourceSentence;
  final Value<String?> sourceTitle;
  final Value<int> reviewLevel;
  final Value<int> reviewCount;
  final Value<DateTime?> lastReviewedAt;
  final Value<DateTime?> nextReviewAt;
  final Value<int> rowid;
  const DictionaryWordsCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.language = const Value.absent(),
    this.languageLabel = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceLabel = const Value.absent(),
    this.phonetic = const Value.absent(),
    this.partOfSpeech = const Value.absent(),
    this.definition = const Value.absent(),
    this.fullJson = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.sourceSentence = const Value.absent(),
    this.sourceTitle = const Value.absent(),
    this.reviewLevel = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DictionaryWordsCompanion.insert({
    required String id,
    required String word,
    required String language,
    required String languageLabel,
    this.source = const Value.absent(),
    this.sourceLabel = const Value.absent(),
    this.phonetic = const Value.absent(),
    required String partOfSpeech,
    required String definition,
    required String fullJson,
    required DateTime savedAt,
    this.sourceSentence = const Value.absent(),
    this.sourceTitle = const Value.absent(),
    this.reviewLevel = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       word = Value(word),
       language = Value(language),
       languageLabel = Value(languageLabel),
       partOfSpeech = Value(partOfSpeech),
       definition = Value(definition),
       fullJson = Value(fullJson),
       savedAt = Value(savedAt);
  static Insertable<DictionaryWord> custom({
    Expression<String>? id,
    Expression<String>? word,
    Expression<String>? language,
    Expression<String>? languageLabel,
    Expression<String>? source,
    Expression<String>? sourceLabel,
    Expression<String>? phonetic,
    Expression<String>? partOfSpeech,
    Expression<String>? definition,
    Expression<String>? fullJson,
    Expression<DateTime>? savedAt,
    Expression<String>? sourceSentence,
    Expression<String>? sourceTitle,
    Expression<int>? reviewLevel,
    Expression<int>? reviewCount,
    Expression<DateTime>? lastReviewedAt,
    Expression<DateTime>? nextReviewAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (language != null) 'language': language,
      if (languageLabel != null) 'language_label': languageLabel,
      if (source != null) 'source': source,
      if (sourceLabel != null) 'source_label': sourceLabel,
      if (phonetic != null) 'phonetic': phonetic,
      if (partOfSpeech != null) 'part_of_speech': partOfSpeech,
      if (definition != null) 'definition': definition,
      if (fullJson != null) 'full_json': fullJson,
      if (savedAt != null) 'saved_at': savedAt,
      if (sourceSentence != null) 'source_sentence': sourceSentence,
      if (sourceTitle != null) 'source_title': sourceTitle,
      if (reviewLevel != null) 'review_level': reviewLevel,
      if (reviewCount != null) 'review_count': reviewCount,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DictionaryWordsCompanion copyWith({
    Value<String>? id,
    Value<String>? word,
    Value<String>? language,
    Value<String>? languageLabel,
    Value<String>? source,
    Value<String>? sourceLabel,
    Value<String?>? phonetic,
    Value<String>? partOfSpeech,
    Value<String>? definition,
    Value<String>? fullJson,
    Value<DateTime>? savedAt,
    Value<String?>? sourceSentence,
    Value<String?>? sourceTitle,
    Value<int>? reviewLevel,
    Value<int>? reviewCount,
    Value<DateTime?>? lastReviewedAt,
    Value<DateTime?>? nextReviewAt,
    Value<int>? rowid,
  }) {
    return DictionaryWordsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      language: language ?? this.language,
      languageLabel: languageLabel ?? this.languageLabel,
      source: source ?? this.source,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      phonetic: phonetic ?? this.phonetic,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      definition: definition ?? this.definition,
      fullJson: fullJson ?? this.fullJson,
      savedAt: savedAt ?? this.savedAt,
      sourceSentence: sourceSentence ?? this.sourceSentence,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      reviewLevel: reviewLevel ?? this.reviewLevel,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (languageLabel.present) {
      map['language_label'] = Variable<String>(languageLabel.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceLabel.present) {
      map['source_label'] = Variable<String>(sourceLabel.value);
    }
    if (phonetic.present) {
      map['phonetic'] = Variable<String>(phonetic.value);
    }
    if (partOfSpeech.present) {
      map['part_of_speech'] = Variable<String>(partOfSpeech.value);
    }
    if (definition.present) {
      map['definition'] = Variable<String>(definition.value);
    }
    if (fullJson.present) {
      map['full_json'] = Variable<String>(fullJson.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (sourceSentence.present) {
      map['source_sentence'] = Variable<String>(sourceSentence.value);
    }
    if (sourceTitle.present) {
      map['source_title'] = Variable<String>(sourceTitle.value);
    }
    if (reviewLevel.present) {
      map['review_level'] = Variable<int>(reviewLevel.value);
    }
    if (reviewCount.present) {
      map['review_count'] = Variable<int>(reviewCount.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<DateTime>(nextReviewAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryWordsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('language: $language, ')
          ..write('languageLabel: $languageLabel, ')
          ..write('source: $source, ')
          ..write('sourceLabel: $sourceLabel, ')
          ..write('phonetic: $phonetic, ')
          ..write('partOfSpeech: $partOfSpeech, ')
          ..write('definition: $definition, ')
          ..write('fullJson: $fullJson, ')
          ..write('savedAt: $savedAt, ')
          ..write('sourceSentence: $sourceSentence, ')
          ..write('sourceTitle: $sourceTitle, ')
          ..write('reviewLevel: $reviewLevel, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WebHistoryTable extends WebHistory
    with TableInfo<$WebHistoryTable, WebHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WebHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visitedAtMeta = const VerificationMeta(
    'visitedAt',
  );
  @override
  late final GeneratedColumn<DateTime> visitedAt = GeneratedColumn<DateTime>(
    'visited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, url, title, visitedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'web_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<WebHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('visited_at')) {
      context.handle(
        _visitedAtMeta,
        visitedAt.isAcceptableOrUnknown(data['visited_at']!, _visitedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_visitedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WebHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WebHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      visitedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}visited_at'],
      )!,
    );
  }

  @override
  $WebHistoryTable createAlias(String alias) {
    return $WebHistoryTable(attachedDatabase, alias);
  }
}

class WebHistoryData extends DataClass implements Insertable<WebHistoryData> {
  final String id;
  final String url;
  final String? title;
  final DateTime visitedAt;
  const WebHistoryData({
    required this.id,
    required this.url,
    this.title,
    required this.visitedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['visited_at'] = Variable<DateTime>(visitedAt);
    return map;
  }

  WebHistoryCompanion toCompanion(bool nullToAbsent) {
    return WebHistoryCompanion(
      id: Value(id),
      url: Value(url),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      visitedAt: Value(visitedAt),
    );
  }

  factory WebHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WebHistoryData(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      title: serializer.fromJson<String?>(json['title']),
      visitedAt: serializer.fromJson<DateTime>(json['visitedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'title': serializer.toJson<String?>(title),
      'visitedAt': serializer.toJson<DateTime>(visitedAt),
    };
  }

  WebHistoryData copyWith({
    String? id,
    String? url,
    Value<String?> title = const Value.absent(),
    DateTime? visitedAt,
  }) => WebHistoryData(
    id: id ?? this.id,
    url: url ?? this.url,
    title: title.present ? title.value : this.title,
    visitedAt: visitedAt ?? this.visitedAt,
  );
  WebHistoryData copyWithCompanion(WebHistoryCompanion data) {
    return WebHistoryData(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      visitedAt: data.visitedAt.present ? data.visitedAt.value : this.visitedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WebHistoryData(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('visitedAt: $visitedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, url, title, visitedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WebHistoryData &&
          other.id == this.id &&
          other.url == this.url &&
          other.title == this.title &&
          other.visitedAt == this.visitedAt);
}

class WebHistoryCompanion extends UpdateCompanion<WebHistoryData> {
  final Value<String> id;
  final Value<String> url;
  final Value<String?> title;
  final Value<DateTime> visitedAt;
  final Value<int> rowid;
  const WebHistoryCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.visitedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WebHistoryCompanion.insert({
    required String id,
    required String url,
    this.title = const Value.absent(),
    required DateTime visitedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       visitedAt = Value(visitedAt);
  static Insertable<WebHistoryData> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? title,
    Expression<DateTime>? visitedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (visitedAt != null) 'visited_at': visitedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WebHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String?>? title,
    Value<DateTime>? visitedAt,
    Value<int>? rowid,
  }) {
    return WebHistoryCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      visitedAt: visitedAt ?? this.visitedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (visitedAt.present) {
      map['visited_at'] = Variable<DateTime>(visitedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WebHistoryCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('visitedAt: $visitedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WebBookmarksTable extends WebBookmarks
    with TableInfo<$WebBookmarksTable, WebBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WebBookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
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
  List<GeneratedColumn> get $columns => [id, url, title, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'web_bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<WebBookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
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
  WebBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WebBookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
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
  $WebBookmarksTable createAlias(String alias) {
    return $WebBookmarksTable(attachedDatabase, alias);
  }
}

class WebBookmark extends DataClass implements Insertable<WebBookmark> {
  final String id;
  final String url;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WebBookmark({
    required this.id,
    required this.url,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WebBookmarksCompanion toCompanion(bool nullToAbsent) {
    return WebBookmarksCompanion(
      id: Value(id),
      url: Value(url),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WebBookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WebBookmark(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      title: serializer.fromJson<String?>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'title': serializer.toJson<String?>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WebBookmark copyWith({
    String? id,
    String? url,
    Value<String?> title = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WebBookmark(
    id: id ?? this.id,
    url: url ?? this.url,
    title: title.present ? title.value : this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WebBookmark copyWithCompanion(WebBookmarksCompanion data) {
    return WebBookmark(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WebBookmark(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, url, title, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WebBookmark &&
          other.id == this.id &&
          other.url == this.url &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WebBookmarksCompanion extends UpdateCompanion<WebBookmark> {
  final Value<String> id;
  final Value<String> url;
  final Value<String?> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WebBookmarksCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WebBookmarksCompanion.insert({
    required String id,
    required String url,
    this.title = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WebBookmark> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WebBookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String?>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WebBookmarksCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
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
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
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
    return (StringBuffer('WebBookmarksCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WebTabsTable extends WebTabs with TableInfo<$WebTabsTable, WebTab> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WebTabsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastActiveAtMeta = const VerificationMeta(
    'lastActiveAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastActiveAt = GeneratedColumn<DateTime>(
    'last_active_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, url, title, order, lastActiveAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'web_tabs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WebTab> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    if (data.containsKey('last_active_at')) {
      context.handle(
        _lastActiveAtMeta,
        lastActiveAt.isAcceptableOrUnknown(
          data['last_active_at']!,
          _lastActiveAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastActiveAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WebTab map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WebTab(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      )!,
      lastActiveAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_active_at'],
      )!,
    );
  }

  @override
  $WebTabsTable createAlias(String alias) {
    return $WebTabsTable(attachedDatabase, alias);
  }
}

class WebTab extends DataClass implements Insertable<WebTab> {
  final String id;
  final String? url;
  final String? title;
  final int order;
  final DateTime lastActiveAt;
  const WebTab({
    required this.id,
    this.url,
    this.title,
    required this.order,
    required this.lastActiveAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['order'] = Variable<int>(order);
    map['last_active_at'] = Variable<DateTime>(lastActiveAt);
    return map;
  }

  WebTabsCompanion toCompanion(bool nullToAbsent) {
    return WebTabsCompanion(
      id: Value(id),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      order: Value(order),
      lastActiveAt: Value(lastActiveAt),
    );
  }

  factory WebTab.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WebTab(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String?>(json['url']),
      title: serializer.fromJson<String?>(json['title']),
      order: serializer.fromJson<int>(json['order']),
      lastActiveAt: serializer.fromJson<DateTime>(json['lastActiveAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String?>(url),
      'title': serializer.toJson<String?>(title),
      'order': serializer.toJson<int>(order),
      'lastActiveAt': serializer.toJson<DateTime>(lastActiveAt),
    };
  }

  WebTab copyWith({
    String? id,
    Value<String?> url = const Value.absent(),
    Value<String?> title = const Value.absent(),
    int? order,
    DateTime? lastActiveAt,
  }) => WebTab(
    id: id ?? this.id,
    url: url.present ? url.value : this.url,
    title: title.present ? title.value : this.title,
    order: order ?? this.order,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
  );
  WebTab copyWithCompanion(WebTabsCompanion data) {
    return WebTab(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      order: data.order.present ? data.order.value : this.order,
      lastActiveAt: data.lastActiveAt.present
          ? data.lastActiveAt.value
          : this.lastActiveAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WebTab(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('order: $order, ')
          ..write('lastActiveAt: $lastActiveAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, url, title, order, lastActiveAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WebTab &&
          other.id == this.id &&
          other.url == this.url &&
          other.title == this.title &&
          other.order == this.order &&
          other.lastActiveAt == this.lastActiveAt);
}

class WebTabsCompanion extends UpdateCompanion<WebTab> {
  final Value<String> id;
  final Value<String?> url;
  final Value<String?> title;
  final Value<int> order;
  final Value<DateTime> lastActiveAt;
  final Value<int> rowid;
  const WebTabsCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.order = const Value.absent(),
    this.lastActiveAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WebTabsCompanion.insert({
    required String id,
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    required int order,
    required DateTime lastActiveAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       order = Value(order),
       lastActiveAt = Value(lastActiveAt);
  static Insertable<WebTab> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? title,
    Expression<int>? order,
    Expression<DateTime>? lastActiveAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (order != null) 'order': order,
      if (lastActiveAt != null) 'last_active_at': lastActiveAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WebTabsCompanion copyWith({
    Value<String>? id,
    Value<String?>? url,
    Value<String?>? title,
    Value<int>? order,
    Value<DateTime>? lastActiveAt,
    Value<int>? rowid,
  }) {
    return WebTabsCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      order: order ?? this.order,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (lastActiveAt.present) {
      map['last_active_at'] = Variable<DateTime>(lastActiveAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WebTabsCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('order: $order, ')
          ..write('lastActiveAt: $lastActiveAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $DictionaryWordsTable dictionaryWords = $DictionaryWordsTable(
    this,
  );
  late final $WebHistoryTable webHistory = $WebHistoryTable(this);
  late final $WebBookmarksTable webBookmarks = $WebBookmarksTable(this);
  late final $WebTabsTable webTabs = $WebTabsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    chapters,
    readingProgress,
    bookmarks,
    appSettings,
    characters,
    dictionaryWords,
    webHistory,
    webBookmarks,
    webTabs,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String id,
      required String title,
      Value<String?> author,
      Value<String?> coverPath,
      Value<String?> description,
      required String format,
      required String filePath,
      Value<String> itemType,
      Value<int?> fileSize,
      required int totalChapters,
      Value<String?> language,
      Value<String?> tags,
      Value<String?> sourceName,
      Value<String?> sourceId,
      Value<String?> sourceUrl,
      Value<double?> rating,
      Value<String?> status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> author,
      Value<String?> coverPath,
      Value<String?> description,
      Value<String> format,
      Value<String> filePath,
      Value<String> itemType,
      Value<int?> fileSize,
      Value<int> totalChapters,
      Value<String?> language,
      Value<String?> tags,
      Value<String?> sourceName,
      Value<String?> sourceId,
      Value<String?> sourceUrl,
      Value<double?> rating,
      Value<String?> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });

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

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
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

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
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

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
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

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
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

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
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
          (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
          Book,
          PrefetchHooks Function()
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
                Value<String?> coverPath = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> sourceName = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                author: author,
                coverPath: coverPath,
                description: description,
                format: format,
                filePath: filePath,
                itemType: itemType,
                fileSize: fileSize,
                totalChapters: totalChapters,
                language: language,
                tags: tags,
                sourceName: sourceName,
                sourceId: sourceId,
                sourceUrl: sourceUrl,
                rating: rating,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required String format,
                required String filePath,
                Value<String> itemType = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                required int totalChapters,
                Value<String?> language = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> sourceName = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                author: author,
                coverPath: coverPath,
                description: description,
                format: format,
                filePath: filePath,
                itemType: itemType,
                fileSize: fileSize,
                totalChapters: totalChapters,
                language: language,
                tags: tags,
                sourceName: sourceName,
                sourceId: sourceId,
                sourceUrl: sourceUrl,
                rating: rating,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
      Book,
      PrefetchHooks Function()
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      required String id,
      required String bookId,
      required int index,
      required String title,
      required String contentPath,
      required int wordCount,
      Value<int> contentState,
      required int pageCount,
      required DateTime createdAt,
      Value<int> version,
      Value<String?> checksum,
      Value<String?> previousVersionRef,
      Value<int> rowid,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> index,
      Value<String> title,
      Value<String> contentPath,
      Value<int> wordCount,
      Value<int> contentState,
      Value<int> pageCount,
      Value<DateTime> createdAt,
      Value<int> version,
      Value<String?> checksum,
      Value<String?> previousVersionRef,
      Value<int> rowid,
    });

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
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

  ColumnFilters<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentPath => $composableBuilder(
    column: $table.contentPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentState => $composableBuilder(
    column: $table.contentState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousVersionRef => $composableBuilder(
    column: $table.previousVersionRef,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
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

  ColumnOrderings<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentPath => $composableBuilder(
    column: $table.contentPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentState => $composableBuilder(
    column: $table.contentState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousVersionRef => $composableBuilder(
    column: $table.previousVersionRef,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
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

  GeneratedColumn<int> get index =>
      $composableBuilder(column: $table.index, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contentPath => $composableBuilder(
    column: $table.contentPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<int> get contentState => $composableBuilder(
    column: $table.contentState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get previousVersionRef => $composableBuilder(
    column: $table.previousVersionRef,
    builder: (column) => column,
  );
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
          Chapter,
          PrefetchHooks Function()
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> index = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> contentPath = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<int> contentState = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<String?> previousVersionRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                bookId: bookId,
                index: index,
                title: title,
                contentPath: contentPath,
                wordCount: wordCount,
                contentState: contentState,
                pageCount: pageCount,
                createdAt: createdAt,
                version: version,
                checksum: checksum,
                previousVersionRef: previousVersionRef,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int index,
                required String title,
                required String contentPath,
                required int wordCount,
                Value<int> contentState = const Value.absent(),
                required int pageCount,
                required DateTime createdAt,
                Value<int> version = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<String?> previousVersionRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                bookId: bookId,
                index: index,
                title: title,
                contentPath: contentPath,
                wordCount: wordCount,
                contentState: contentState,
                pageCount: pageCount,
                createdAt: createdAt,
                version: version,
                checksum: checksum,
                previousVersionRef: previousVersionRef,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
      Chapter,
      PrefetchHooks Function()
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      required String id,
      required String bookId,
      required String chapterId,
      required double percentage,
      required int position,
      required int totalPositions,
      required DateTime lastReadAt,
      required int readingTimeSeconds,
      Value<bool> isCompleted,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> chapterId,
      Value<double> percentage,
      Value<int> position,
      Value<int> totalPositions,
      Value<DateTime> lastReadAt,
      Value<int> readingTimeSeconds,
      Value<bool> isCompleted,
      Value<int> rowid,
    });

class $$ReadingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
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

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPositions => $composableBuilder(
    column: $table.totalPositions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
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

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPositions => $composableBuilder(
    column: $table.totalPositions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
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

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get totalPositions => $composableBuilder(
    column: $table.totalPositions,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (
            ReadingProgressData,
            BaseReferences<
              _$AppDatabase,
              $ReadingProgressTable,
              ReadingProgressData
            >,
          ),
          ReadingProgressData,
          PrefetchHooks Function()
        > {
  $$ReadingProgressTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<double> percentage = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> totalPositions = const Value.absent(),
                Value<DateTime> lastReadAt = const Value.absent(),
                Value<int> readingTimeSeconds = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                percentage: percentage,
                position: position,
                totalPositions: totalPositions,
                lastReadAt: lastReadAt,
                readingTimeSeconds: readingTimeSeconds,
                isCompleted: isCompleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String chapterId,
                required double percentage,
                required int position,
                required int totalPositions,
                required DateTime lastReadAt,
                required int readingTimeSeconds,
                Value<bool> isCompleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                percentage: percentage,
                position: position,
                totalPositions: totalPositions,
                lastReadAt: lastReadAt,
                readingTimeSeconds: readingTimeSeconds,
                isCompleted: isCompleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTable,
      ReadingProgressData,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (
        ReadingProgressData,
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData
        >,
      ),
      ReadingProgressData,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required String bookId,
      required String chapterId,
      required int position,
      Value<String?> note,
      Value<String?> color,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> chapterId,
      Value<int> position,
      Value<String?> note,
      Value<String?> color,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
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
                Value<String> chapterId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                note: note,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String chapterId,
                required int position,
                Value<String?> note = const Value.absent(),
                Value<String?> color = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                note: note,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$CharactersTableCreateCompanionBuilder =
    CharactersCompanion Function({
      required String id,
      required String bookId,
      required String name,
      Value<String?> aliases,
      Value<String?> description,
      Value<String?> role,
      Value<String?> firstAppearance,
      Value<String?> notes,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CharactersTableUpdateCompanionBuilder =
    CharactersCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> name,
      Value<String?> aliases,
      Value<String?> description,
      Value<String?> role,
      Value<String?> firstAppearance,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstAppearance => $composableBuilder(
    column: $table.firstAppearance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
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
}

class $$CharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstAppearance => $composableBuilder(
    column: $table.firstAppearance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
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
}

class $$CharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableAnnotationComposer({
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get aliases =>
      $composableBuilder(column: $table.aliases, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get firstAppearance => $composableBuilder(
    column: $table.firstAppearance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharactersTable,
          Character,
          $$CharactersTableFilterComposer,
          $$CharactersTableOrderingComposer,
          $$CharactersTableAnnotationComposer,
          $$CharactersTableCreateCompanionBuilder,
          $$CharactersTableUpdateCompanionBuilder,
          (
            Character,
            BaseReferences<_$AppDatabase, $CharactersTable, Character>,
          ),
          Character,
          PrefetchHooks Function()
        > {
  $$CharactersTableTableManager(_$AppDatabase db, $CharactersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> aliases = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> firstAppearance = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion(
                id: id,
                bookId: bookId,
                name: name,
                aliases: aliases,
                description: description,
                role: role,
                firstAppearance: firstAppearance,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String name,
                Value<String?> aliases = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> firstAppearance = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion.insert(
                id: id,
                bookId: bookId,
                name: name,
                aliases: aliases,
                description: description,
                role: role,
                firstAppearance: firstAppearance,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharactersTable,
      Character,
      $$CharactersTableFilterComposer,
      $$CharactersTableOrderingComposer,
      $$CharactersTableAnnotationComposer,
      $$CharactersTableCreateCompanionBuilder,
      $$CharactersTableUpdateCompanionBuilder,
      (Character, BaseReferences<_$AppDatabase, $CharactersTable, Character>),
      Character,
      PrefetchHooks Function()
    >;
typedef $$DictionaryWordsTableCreateCompanionBuilder =
    DictionaryWordsCompanion Function({
      required String id,
      required String word,
      required String language,
      required String languageLabel,
      Value<String> source,
      Value<String> sourceLabel,
      Value<String?> phonetic,
      required String partOfSpeech,
      required String definition,
      required String fullJson,
      required DateTime savedAt,
      Value<String?> sourceSentence,
      Value<String?> sourceTitle,
      Value<int> reviewLevel,
      Value<int> reviewCount,
      Value<DateTime?> lastReviewedAt,
      Value<DateTime?> nextReviewAt,
      Value<int> rowid,
    });
typedef $$DictionaryWordsTableUpdateCompanionBuilder =
    DictionaryWordsCompanion Function({
      Value<String> id,
      Value<String> word,
      Value<String> language,
      Value<String> languageLabel,
      Value<String> source,
      Value<String> sourceLabel,
      Value<String?> phonetic,
      Value<String> partOfSpeech,
      Value<String> definition,
      Value<String> fullJson,
      Value<DateTime> savedAt,
      Value<String?> sourceSentence,
      Value<String?> sourceTitle,
      Value<int> reviewLevel,
      Value<int> reviewCount,
      Value<DateTime?> lastReviewedAt,
      Value<DateTime?> nextReviewAt,
      Value<int> rowid,
    });

class $$DictionaryWordsTableFilterComposer
    extends Composer<_$AppDatabase, $DictionaryWordsTable> {
  $$DictionaryWordsTableFilterComposer({
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

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageLabel => $composableBuilder(
    column: $table.languageLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phonetic => $composableBuilder(
    column: $table.phonetic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullJson => $composableBuilder(
    column: $table.fullJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewLevel => $composableBuilder(
    column: $table.reviewLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DictionaryWordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DictionaryWordsTable> {
  $$DictionaryWordsTableOrderingComposer({
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

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageLabel => $composableBuilder(
    column: $table.languageLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phonetic => $composableBuilder(
    column: $table.phonetic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullJson => $composableBuilder(
    column: $table.fullJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewLevel => $composableBuilder(
    column: $table.reviewLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DictionaryWordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DictionaryWordsTable> {
  $$DictionaryWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get languageLabel => $composableBuilder(
    column: $table.languageLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phonetic =>
      $composableBuilder(column: $table.phonetic, builder: (column) => column);

  GeneratedColumn<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fullJson =>
      $composableBuilder(column: $table.fullJson, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reviewLevel => $composableBuilder(
    column: $table.reviewLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => column,
  );
}

class $$DictionaryWordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DictionaryWordsTable,
          DictionaryWord,
          $$DictionaryWordsTableFilterComposer,
          $$DictionaryWordsTableOrderingComposer,
          $$DictionaryWordsTableAnnotationComposer,
          $$DictionaryWordsTableCreateCompanionBuilder,
          $$DictionaryWordsTableUpdateCompanionBuilder,
          (
            DictionaryWord,
            BaseReferences<
              _$AppDatabase,
              $DictionaryWordsTable,
              DictionaryWord
            >,
          ),
          DictionaryWord,
          PrefetchHooks Function()
        > {
  $$DictionaryWordsTableTableManager(
    _$AppDatabase db,
    $DictionaryWordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionaryWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictionaryWordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictionaryWordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> languageLabel = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceLabel = const Value.absent(),
                Value<String?> phonetic = const Value.absent(),
                Value<String> partOfSpeech = const Value.absent(),
                Value<String> definition = const Value.absent(),
                Value<String> fullJson = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<String?> sourceSentence = const Value.absent(),
                Value<String?> sourceTitle = const Value.absent(),
                Value<int> reviewLevel = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<DateTime?> nextReviewAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DictionaryWordsCompanion(
                id: id,
                word: word,
                language: language,
                languageLabel: languageLabel,
                source: source,
                sourceLabel: sourceLabel,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                definition: definition,
                fullJson: fullJson,
                savedAt: savedAt,
                sourceSentence: sourceSentence,
                sourceTitle: sourceTitle,
                reviewLevel: reviewLevel,
                reviewCount: reviewCount,
                lastReviewedAt: lastReviewedAt,
                nextReviewAt: nextReviewAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String word,
                required String language,
                required String languageLabel,
                Value<String> source = const Value.absent(),
                Value<String> sourceLabel = const Value.absent(),
                Value<String?> phonetic = const Value.absent(),
                required String partOfSpeech,
                required String definition,
                required String fullJson,
                required DateTime savedAt,
                Value<String?> sourceSentence = const Value.absent(),
                Value<String?> sourceTitle = const Value.absent(),
                Value<int> reviewLevel = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<DateTime?> nextReviewAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DictionaryWordsCompanion.insert(
                id: id,
                word: word,
                language: language,
                languageLabel: languageLabel,
                source: source,
                sourceLabel: sourceLabel,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                definition: definition,
                fullJson: fullJson,
                savedAt: savedAt,
                sourceSentence: sourceSentence,
                sourceTitle: sourceTitle,
                reviewLevel: reviewLevel,
                reviewCount: reviewCount,
                lastReviewedAt: lastReviewedAt,
                nextReviewAt: nextReviewAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DictionaryWordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DictionaryWordsTable,
      DictionaryWord,
      $$DictionaryWordsTableFilterComposer,
      $$DictionaryWordsTableOrderingComposer,
      $$DictionaryWordsTableAnnotationComposer,
      $$DictionaryWordsTableCreateCompanionBuilder,
      $$DictionaryWordsTableUpdateCompanionBuilder,
      (
        DictionaryWord,
        BaseReferences<_$AppDatabase, $DictionaryWordsTable, DictionaryWord>,
      ),
      DictionaryWord,
      PrefetchHooks Function()
    >;
typedef $$WebHistoryTableCreateCompanionBuilder =
    WebHistoryCompanion Function({
      required String id,
      required String url,
      Value<String?> title,
      required DateTime visitedAt,
      Value<int> rowid,
    });
typedef $$WebHistoryTableUpdateCompanionBuilder =
    WebHistoryCompanion Function({
      Value<String> id,
      Value<String> url,
      Value<String?> title,
      Value<DateTime> visitedAt,
      Value<int> rowid,
    });

class $$WebHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $WebHistoryTable> {
  $$WebHistoryTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WebHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $WebHistoryTable> {
  $$WebHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WebHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $WebHistoryTable> {
  $$WebHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get visitedAt =>
      $composableBuilder(column: $table.visitedAt, builder: (column) => column);
}

class $$WebHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WebHistoryTable,
          WebHistoryData,
          $$WebHistoryTableFilterComposer,
          $$WebHistoryTableOrderingComposer,
          $$WebHistoryTableAnnotationComposer,
          $$WebHistoryTableCreateCompanionBuilder,
          $$WebHistoryTableUpdateCompanionBuilder,
          (
            WebHistoryData,
            BaseReferences<_$AppDatabase, $WebHistoryTable, WebHistoryData>,
          ),
          WebHistoryData,
          PrefetchHooks Function()
        > {
  $$WebHistoryTableTableManager(_$AppDatabase db, $WebHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WebHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WebHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WebHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<DateTime> visitedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WebHistoryCompanion(
                id: id,
                url: url,
                title: title,
                visitedAt: visitedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                Value<String?> title = const Value.absent(),
                required DateTime visitedAt,
                Value<int> rowid = const Value.absent(),
              }) => WebHistoryCompanion.insert(
                id: id,
                url: url,
                title: title,
                visitedAt: visitedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WebHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WebHistoryTable,
      WebHistoryData,
      $$WebHistoryTableFilterComposer,
      $$WebHistoryTableOrderingComposer,
      $$WebHistoryTableAnnotationComposer,
      $$WebHistoryTableCreateCompanionBuilder,
      $$WebHistoryTableUpdateCompanionBuilder,
      (
        WebHistoryData,
        BaseReferences<_$AppDatabase, $WebHistoryTable, WebHistoryData>,
      ),
      WebHistoryData,
      PrefetchHooks Function()
    >;
typedef $$WebBookmarksTableCreateCompanionBuilder =
    WebBookmarksCompanion Function({
      required String id,
      required String url,
      Value<String?> title,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WebBookmarksTableUpdateCompanionBuilder =
    WebBookmarksCompanion Function({
      Value<String> id,
      Value<String> url,
      Value<String?> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$WebBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $WebBookmarksTable> {
  $$WebBookmarksTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
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
}

class $$WebBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $WebBookmarksTable> {
  $$WebBookmarksTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
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
}

class $$WebBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WebBookmarksTable> {
  $$WebBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WebBookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WebBookmarksTable,
          WebBookmark,
          $$WebBookmarksTableFilterComposer,
          $$WebBookmarksTableOrderingComposer,
          $$WebBookmarksTableAnnotationComposer,
          $$WebBookmarksTableCreateCompanionBuilder,
          $$WebBookmarksTableUpdateCompanionBuilder,
          (
            WebBookmark,
            BaseReferences<_$AppDatabase, $WebBookmarksTable, WebBookmark>,
          ),
          WebBookmark,
          PrefetchHooks Function()
        > {
  $$WebBookmarksTableTableManager(_$AppDatabase db, $WebBookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WebBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WebBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WebBookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WebBookmarksCompanion(
                id: id,
                url: url,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                Value<String?> title = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WebBookmarksCompanion.insert(
                id: id,
                url: url,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WebBookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WebBookmarksTable,
      WebBookmark,
      $$WebBookmarksTableFilterComposer,
      $$WebBookmarksTableOrderingComposer,
      $$WebBookmarksTableAnnotationComposer,
      $$WebBookmarksTableCreateCompanionBuilder,
      $$WebBookmarksTableUpdateCompanionBuilder,
      (
        WebBookmark,
        BaseReferences<_$AppDatabase, $WebBookmarksTable, WebBookmark>,
      ),
      WebBookmark,
      PrefetchHooks Function()
    >;
typedef $$WebTabsTableCreateCompanionBuilder =
    WebTabsCompanion Function({
      required String id,
      Value<String?> url,
      Value<String?> title,
      required int order,
      required DateTime lastActiveAt,
      Value<int> rowid,
    });
typedef $$WebTabsTableUpdateCompanionBuilder =
    WebTabsCompanion Function({
      Value<String> id,
      Value<String?> url,
      Value<String?> title,
      Value<int> order,
      Value<DateTime> lastActiveAt,
      Value<int> rowid,
    });

class $$WebTabsTableFilterComposer
    extends Composer<_$AppDatabase, $WebTabsTable> {
  $$WebTabsTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastActiveAt => $composableBuilder(
    column: $table.lastActiveAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WebTabsTableOrderingComposer
    extends Composer<_$AppDatabase, $WebTabsTable> {
  $$WebTabsTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastActiveAt => $composableBuilder(
    column: $table.lastActiveAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WebTabsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WebTabsTable> {
  $$WebTabsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActiveAt => $composableBuilder(
    column: $table.lastActiveAt,
    builder: (column) => column,
  );
}

class $$WebTabsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WebTabsTable,
          WebTab,
          $$WebTabsTableFilterComposer,
          $$WebTabsTableOrderingComposer,
          $$WebTabsTableAnnotationComposer,
          $$WebTabsTableCreateCompanionBuilder,
          $$WebTabsTableUpdateCompanionBuilder,
          (WebTab, BaseReferences<_$AppDatabase, $WebTabsTable, WebTab>),
          WebTab,
          PrefetchHooks Function()
        > {
  $$WebTabsTableTableManager(_$AppDatabase db, $WebTabsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WebTabsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WebTabsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WebTabsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int> order = const Value.absent(),
                Value<DateTime> lastActiveAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WebTabsCompanion(
                id: id,
                url: url,
                title: title,
                order: order,
                lastActiveAt: lastActiveAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> url = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required int order,
                required DateTime lastActiveAt,
                Value<int> rowid = const Value.absent(),
              }) => WebTabsCompanion.insert(
                id: id,
                url: url,
                title: title,
                order: order,
                lastActiveAt: lastActiveAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WebTabsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WebTabsTable,
      WebTab,
      $$WebTabsTableFilterComposer,
      $$WebTabsTableOrderingComposer,
      $$WebTabsTableAnnotationComposer,
      $$WebTabsTableCreateCompanionBuilder,
      $$WebTabsTableUpdateCompanionBuilder,
      (WebTab, BaseReferences<_$AppDatabase, $WebTabsTable, WebTab>),
      WebTab,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$DictionaryWordsTableTableManager get dictionaryWords =>
      $$DictionaryWordsTableTableManager(_db, _db.dictionaryWords);
  $$WebHistoryTableTableManager get webHistory =>
      $$WebHistoryTableTableManager(_db, _db.webHistory);
  $$WebBookmarksTableTableManager get webBookmarks =>
      $$WebBookmarksTableTableManager(_db, _db.webBookmarks);
  $$WebTabsTableTableManager get webTabs =>
      $$WebTabsTableTableManager(_db, _db.webTabs);
}
