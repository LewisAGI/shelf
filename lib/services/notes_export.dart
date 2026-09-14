import 'dart:convert';
import 'dart:io';

import '../models/color_label.dart';
import '../models/library_document.dart';
import '../models/note.dart';

/// JSON + markdown schema for one book's notes.
class NotesExport {
  static const schemaId = 'shelf-notes-v1';

  static String safeFileStem(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return cleaned.isEmpty ? 'shelf-notes' : cleaned;
  }

  static Map<String, Object?> payload({
    required LibraryDocument document,
    required List<Note> notes,
    required ColorLabel Function(String id) labelById,
    DateTime? exportedAt,
  }) {
    final at = exportedAt ?? DateTime.now().toUtc();
    final sorted = [...notes]
      ..sort((a, b) {
        final page = a.page.compareTo(b.page);
        if (page != 0) {
          return page;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    return {
      'schema': schemaId,
      'exported_at': at.toIso8601String(),
      'document': {
        'id': document.id,
        'title': document.title,
        'page_count': document.pageCount,
        'imported_at': document.importedAt.toUtc().toIso8601String(),
      },
      'notes': [
        for (final note in sorted) _noteJson(note, labelById(note.colorLabelId)),
      ],
    };
  }

  static String jsonString({
    required LibraryDocument document,
    required List<Note> notes,
    required ColorLabel Function(String id) labelById,
    DateTime? exportedAt,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      payload(
        document: document,
        notes: notes,
        labelById: labelById,
        exportedAt: exportedAt,
      ),
    );
  }

  static String schemaMarkdown({String documentTitle = 'this book'}) {
    return '''
# Shelf notes export schema (`$schemaId`)

This markdown is a short companion to the JSON export for **$documentTitle**.
Give both files to a model so it can read the notes.

## Root

- `schema` — always `$schemaId`
- `exported_at` — ISO-8601 UTC timestamp
- `document` — `{ id, title, page_count, imported_at }`
- `notes` — array of comments on that PDF, page then created-at order

## Each note

- `id` — stable local id
- `page` — 1-based PDF page
- `x`, `y` — normalised marker position, origin top-left, range 0–1
- `text` — the reader's comment
- `selected_text` — quoted page text when the note is selection-anchored; otherwise null
- `selection` — `{ left, top, right, bottom }` normalised page box, or null
- `label` — `{ id, name, meaning, hex }` colour label at export time
- `created_at`, `updated_at` — ISO-8601 UTC

Coordinates are page-relative, not pixels. There is no house-paid AI in this export.
''';
  }

  static Future<List<File>> writeFiles({
    required LibraryDocument document,
    required List<Note> notes,
    required ColorLabel Function(String id) labelById,
    Directory? directory,
    DateTime? exportedAt,
  }) async {
    final dir = directory ?? await Directory.systemTemp.createTemp('shelf-export-');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final stem = safeFileStem(document.title);
    final jsonFile = File('${dir.path}/$stem-notes.json');
    final mdFile = File('${dir.path}/$stem-notes-schema.md');
    await jsonFile.writeAsString(
      jsonString(
        document: document,
        notes: notes,
        labelById: labelById,
        exportedAt: exportedAt,
      ),
    );
    await mdFile.writeAsString(schemaMarkdown(documentTitle: document.title));
    return [jsonFile, mdFile];
  }

  static Map<String, Object?> _noteJson(Note note, ColorLabel label) {
    return {
      'id': note.id,
      'page': note.page,
      'x': note.x,
      'y': note.y,
      'text': note.text,
      'selected_text': note.selection?.text,
      'selection': note.selection == null
          ? null
          : {
              'left': note.selection!.left,
              'top': note.selection!.top,
              'right': note.selection!.right,
              'bottom': note.selection!.bottom,
            },
      'label': {
        'id': label.id,
        'name': label.name,
        'meaning': label.meaning,
        'hex': label.hex,
      },
      'created_at': note.createdAt.toUtc().toIso8601String(),
      'updated_at': note.updatedAt.toUtc().toIso8601String(),
    };
  }
}
