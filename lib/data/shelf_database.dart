import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/color_label.dart';
import '../models/library_document.dart';
import '../models/note.dart';

class ShelfDatabase {
  ShelfDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _overridePath = path;

  static const _uuid = Uuid();

  final DatabaseFactory _factory;
  final String? _overridePath;
  Database? _db;

  static String newId() => _uuid.v4();

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) {
      return existing;
    }
    final opened = await _open();
    _db = opened;
    return opened;
  }

  Future<Database> _open() async {
    final dbPath = _overridePath ?? await _defaultPath();
    return _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              stored_name TEXT NOT NULL,
              imported_at INTEGER NOT NULL,
              page_count INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE color_labels (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              meaning TEXT NOT NULL,
              hex TEXT NOT NULL,
              is_default INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE notes (
              id TEXT PRIMARY KEY,
              document_id TEXT NOT NULL,
              page INTEGER NOT NULL,
              x REAL NOT NULL,
              y REAL NOT NULL,
              text TEXT NOT NULL,
              color_label_id TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
              FOREIGN KEY(color_label_id) REFERENCES color_labels(id)
            )
          ''');
          await _seedLabels(db);
        },
      ),
    );
  }

  Future<String> _defaultPath() async {
    final databasesPath = await getDatabasesPath();
    return p.join(databasesPath, 'shelf.db');
  }

  Future<Directory> libraryDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'library'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> pdfPathFor(LibraryDocument document) async {
    final dir = await libraryDirectory();
    return p.join(dir.path, document.storedName);
  }

  Future<void> _seedLabels(Database db) async {
    for (final label in ColorLabel.seedDefaults()) {
      await db.insert('color_labels', label.toMap());
    }
  }

  Future<List<LibraryDocument>> loadDocuments() async {
    final db = await database;
    final rows = await db.query('documents', orderBy: 'imported_at DESC');
    return rows.map(LibraryDocument.fromMap).toList();
  }

  Future<void> upsertDocument(LibraryDocument document) async {
    final db = await database;
    await db.insert(
      'documents',
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> loadNotes() async {
    final db = await database;
    final rows = await db.query('notes', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<void> upsertNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ColorLabel>> loadLabels() async {
    final db = await database;
    final rows = await db.query('color_labels', orderBy: 'sort_order ASC');
    if (rows.isEmpty) {
      await _seedLabels(db);
      return ColorLabel.seedDefaults();
    }
    return rows.map(ColorLabel.fromMap).toList();
  }

  Future<void> upsertLabel(ColorLabel label) async {
    final db = await database;
    await db.transaction((txn) async {
      if (label.isDefault) {
        await txn.update('color_labels', {'is_default': 0});
      }
      await txn.insert(
        'color_labels',
        label.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteLabel(String id, {required String fallbackId}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'notes',
        {'color_label_id': fallbackId},
        where: 'color_label_id = ?',
        whereArgs: [id],
      );
      await txn.delete('color_labels', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> close() async {
    final existing = _db;
    _db = null;
    if (existing != null) {
      await existing.close();
    }
  }
}
