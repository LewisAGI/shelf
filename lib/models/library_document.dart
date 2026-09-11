class LibraryDocument {
  const LibraryDocument({
    required this.id,
    required this.title,
    required this.storedName,
    required this.importedAt,
    this.pageCount,
  });

  final String id;
  final String title;
  final String storedName;
  final DateTime importedAt;
  final int? pageCount;

  LibraryDocument copyWith({
    String? title,
    String? storedName,
    DateTime? importedAt,
    int? pageCount,
  }) {
    return LibraryDocument(
      id: id,
      title: title ?? this.title,
      storedName: storedName ?? this.storedName,
      importedAt: importedAt ?? this.importedAt,
      pageCount: pageCount ?? this.pageCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'stored_name': storedName,
      'imported_at': importedAt.millisecondsSinceEpoch,
      'page_count': pageCount,
    };
  }

  factory LibraryDocument.fromMap(Map<String, Object?> map) {
    return LibraryDocument(
      id: map['id']! as String,
      title: map['title']! as String,
      storedName: map['stored_name']! as String,
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        map['imported_at']! as int,
      ),
      pageCount: map['page_count'] as int?,
    );
  }
}
