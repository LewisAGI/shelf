import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/ai_provider.dart';
import '../models/color_label.dart';
import '../models/library_document.dart';
import '../models/note.dart';
import 'pdf_section_resolver.dart';

/// What a single-note share attaches besides the JSON.
enum SingleNoteShareKind {
  notePdfGuide,
  notePdf,
  noteGuide,
  noteOnly;

  bool get includePdf =>
      this == SingleNoteShareKind.notePdfGuide ||
      this == SingleNoteShareKind.notePdf;

  bool get includeGuide =>
      this == SingleNoteShareKind.notePdfGuide ||
      this == SingleNoteShareKind.noteGuide;
}

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

  /// Imported PDF filename for JSON / share. Sandbox `{id}.pdf` names are
  /// not useful to a model — prefer the title with a `.pdf` suffix when
  /// [LibraryDocument.storedName] is only the internal copy.
  static String fileNameOf(LibraryDocument document) {
    final stored = document.storedName.trim();
    final title = document.title.trim();
    final titledPdf = _asPdfFileName(title);
    final storedLooksInternal = stored.isEmpty ||
        stored == '${document.id}.pdf' ||
        p.basenameWithoutExtension(stored).toLowerCase() ==
            document.id.toLowerCase();
    if (!storedLooksInternal) {
      return stored;
    }
    if (titledPdf.isNotEmpty) {
      return titledPdf;
    }
    return stored.isEmpty ? 'document.pdf' : stored;
  }

  static String _asPdfFileName(String title) {
    if (title.isEmpty) {
      return '';
    }
    return title.toLowerCase().endsWith('.pdf') ? title : '$title.pdf';
  }

  /// Shared document block for bulk and single-note `shelf-notes-v1`.
  static Map<String, Object?> documentJson(LibraryDocument document) {
    return {
      'id': document.id,
      'title': document.title,
      'file_name': fileNameOf(document),
      'page_count': document.pageCount,
      'imported_at': document.importedAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, Object?> payload({
    required LibraryDocument document,
    required List<Note> notes,
    required ColorLabel Function(String id) labelById,
    DateTime? exportedAt,
    List<PdfSection> outline = const [],
  }) {
    final at = exportedAt ?? DateTime.now().toUtc();
    final sorted = _sorted(notes);
    return {
      'schema': schemaId,
      'exported_at': at.toIso8601String(),
      'document': documentJson(document),
      'notes': [
        for (final note in sorted)
          _noteJson(
            note,
            labelById(note.colorLabelId),
            PdfSectionResolver.forNote(note, outline),
          ),
      ],
    };
  }

  static String jsonString({
    required LibraryDocument document,
    required List<Note> notes,
    required ColorLabel Function(String id) labelById,
    DateTime? exportedAt,
    List<PdfSection> outline = const [],
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      payload(
        document: document,
        notes: notes,
        labelById: labelById,
        exportedAt: exportedAt,
        outline: outline,
      ),
    );
  }

  static String schemaMarkdown({String documentTitle = 'this book'}) {
    return '''
# Shelf notes export schema (`$schemaId`)

This markdown is a short companion to the JSON export for **$documentTitle**.
Give both files to a model so it can read the notes.

A single-note share uses the same shape with one entry in `notes`.

## Root

- `schema` — always `$schemaId`
- `exported_at` — ISO-8601 UTC timestamp
- `document` — `{ id, title, file_name, page_count, imported_at }`
- `file_name` — imported PDF filename; may differ from `title`
- `notes` — array of comments on that PDF, page then created-at order. A single-note share has one item.

## Each note

- `id` — stable local id
- `page` — 1-based PDF page
- `x`, `y` — normalised marker position, origin top-left, range 0–1
- `text` — the reader's comment
- `selected_text` — quoted page text when the note is selection-anchored; otherwise null
- `selection` — `{ left, top, right, bottom }` normalised page box, or null
- `heading` — PDF outline/bookmark chapter the note sits under; null if unknown
- `subheading` — nearest subsection under that heading; null if none or unknown
- `label` — `{ id, name, meaning, hex }` colour label at export time
- `created_at`, `updated_at` — ISO-8601 UTC

Coordinates are page-relative, not pixels. There is no house-paid AI in this export.

`heading` and `subheading` are resolved at export time from the **current** PDF
structure (outline/bookmarks first; pdfrx already resolves named destinations
into destinations). If the file has no outline, Shelf tries title-like lines
on the page. They are not stored on the note. Empty/missing structure is
emitted as JSON null — do not invent a chapter.
''';
  }

  static Future<List<File>> writeFiles({
    required LibraryDocument document,
    required List<Note> notes,
    required ColorLabel Function(String id) labelById,
    Directory? directory,
    DateTime? exportedAt,
    List<PdfSection> outline = const [],
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
        outline: outline,
      ),
    );
    await mdFile.writeAsString(schemaMarkdown(documentTitle: document.title));
    return [jsonFile, mdFile];
  }

  /// One note, same `shelf-notes-v1` envelope. Optionally attach the PDF
  /// and/or the schema companion — same files a bulk export would share.
  static Future<List<File>> writeSingleNoteFiles({
    required LibraryDocument document,
    required Note note,
    required ColorLabel Function(String id) labelById,
    required SingleNoteShareKind kind,
    Directory? directory,
    DateTime? exportedAt,
    List<PdfSection> outline = const [],
    List<int>? pdfBytes,
    File? pdfFile,
  }) async {
    final dir = directory ?? await Directory.systemTemp.createTemp('shelf-export-');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final stem = safeFileStem(document.title);
    final files = <File>[];
    final jsonFile = File('${dir.path}/$stem-note.json');
    await jsonFile.writeAsString(
      jsonString(
        document: document,
        notes: [note],
        labelById: labelById,
        exportedAt: exportedAt,
        outline: outline,
      ),
    );
    files.add(jsonFile);
    if (kind.includeGuide) {
      final mdFile = File('${dir.path}/$stem-note-schema.md');
      await mdFile.writeAsString(schemaMarkdown(documentTitle: document.title));
      files.add(mdFile);
    }
    if (kind.includePdf) {
      final dest = File('${dir.path}/${fileNameOf(document)}');
      if (pdfFile != null && pdfFile.existsSync()) {
        await pdfFile.copy(dest.path);
        files.add(dest);
      } else if (pdfBytes != null && pdfBytes.isNotEmpty) {
        await dest.writeAsBytes(pdfBytes);
        files.add(dest);
      }
    }
    return files;
  }

  /// Book / Send-to-AI snippets with the same heading resolution as export.
  static List<AiNoteSnippet> snippets({
    required List<Note> notes,
    required ColorLabel Function(String id) labelById,
    List<PdfSection> outline = const [],
  }) {
    return [
      for (final note in _sorted(notes))
        snippetFor(note, labelById(note.colorLabelId), outline),
    ];
  }

  static AiNoteSnippet snippetFor(
    Note note,
    ColorLabel label,
    List<PdfSection> outline,
  ) {
    final headings = PdfSectionResolver.forNote(note, outline);
    return AiNoteSnippet(
      text: note.text,
      page: note.page,
      selectedText: note.selection?.text,
      labelName: label.name,
      heading: headings.heading,
      subheading: headings.subheading,
    );
  }

  static List<Note> _sorted(List<Note> notes) {
    final sorted = [...notes]
      ..sort((a, b) {
        final page = a.page.compareTo(b.page);
        if (page != 0) {
          return page;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    return sorted;
  }

  static Map<String, Object?> _noteJson(
    Note note,
    ColorLabel label,
    NoteHeadings headings,
  ) {
    return {
      'id': note.id,
      'page': note.page,
      'x': note.x,
      'y': note.y,
      'text': note.text,
      'heading': headings.heading,
      'subheading': headings.subheading,
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
