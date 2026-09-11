import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../models/color_label.dart';
import '../models/library_document.dart';
import '../models/note.dart';
import 'shelf_database.dart';

class ShelfStore extends ChangeNotifier {
  ShelfStore({ShelfDatabase? database}) : _db = database ?? ShelfDatabase();

  final ShelfDatabase _db;

  final List<LibraryDocument> documents = [];
  final List<Note> notes = [];
  final List<ColorLabel> labels = [];
  bool ready = false;
  String? lastError;

  ColorLabel get defaultLabel {
    return labels.firstWhere(
      (label) => label.isDefault,
      orElse: () =>
          labels.isNotEmpty ? labels.first : ColorLabel.seedDefaults().first,
    );
  }

  ColorLabel labelById(String id) {
    return labels.firstWhere(
      (label) => label.id == id,
      orElse: () => defaultLabel,
    );
  }

  Future<void> init() async {
    documents
      ..clear()
      ..addAll(await _db.loadDocuments());
    labels
      ..clear()
      ..addAll(await _db.loadLabels());
    notes
      ..clear()
      ..addAll(await _db.loadNotes());
    ready = true;
    notifyListeners();
  }

  LibraryDocument? documentById(String id) {
    for (final document in documents) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  List<Note> notesForDocument(String documentId) {
    return notes.where((note) => note.documentId == documentId).toList();
  }

  List<Note> notesOnPage(String documentId, int page) {
    return notes
        .where((note) => note.documentId == documentId && note.page == page)
        .toList();
  }

  List<Note> searchNotes({String query = '', String? colorLabelId}) {
    final needle = query.trim().toLowerCase();
    return notes.where((note) {
      if (colorLabelId != null && note.colorLabelId != colorLabelId) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      final document = documentById(note.documentId);
      final label = labelById(note.colorLabelId);
      final haystack = [
        note.text,
        document?.title ?? '',
        label.name,
        label.meaning,
        'page ${note.page}',
      ].join(' ').toLowerCase();
      return haystack.contains(needle);
    }).toList();
  }

  Future<String> pdfPath(LibraryDocument document) {
    return _db.pdfPathFor(document);
  }

  Future<LibraryDocument?> importPdf() async {
    lastError = null;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }
    final sourcePath = picked.files.single.path;
    if (sourcePath == null) {
      lastError = 'Could not read that file on this device.';
      notifyListeners();
      return null;
    }

    final id = ShelfDatabase.newId();
    final originalName = picked.files.single.name;
    final title = p.basenameWithoutExtension(originalName);
    final storedName = '$id.pdf';
    final dir = await _db.libraryDirectory();
    final destination = File(p.join(dir.path, storedName));
    await File(sourcePath).copy(destination.path);

    var pageCount = 0;
    try {
      final pdf = await PdfDocument.openFile(destination.path);
      pageCount = pdf.pages.length;
      await pdf.dispose();
    } on Object {
      pageCount = 0;
    }

    final document = LibraryDocument(
      id: id,
      title: title.isEmpty ? 'Untitled PDF' : title,
      storedName: storedName,
      importedAt: DateTime.now(),
      pageCount: pageCount == 0 ? null : pageCount,
    );
    await _db.upsertDocument(document);
    documents.insert(0, document);
    notifyListeners();
    return document;
  }

  Future<void> updatePageCount(String documentId, int pageCount) async {
    final index = documents.indexWhere((doc) => doc.id == documentId);
    if (index < 0) {
      return;
    }
    final updated = documents[index].copyWith(pageCount: pageCount);
    documents[index] = updated;
    await _db.upsertDocument(updated);
    notifyListeners();
  }

  Future<void> removeDocument(LibraryDocument document) async {
    try {
      final path = await _db.pdfPathFor(document);
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } on Object {
      // File cleanup is best-effort; the library row still goes.
    }
    await _db.deleteDocument(document.id);
    documents.removeWhere((item) => item.id == document.id);
    notes.removeWhere((note) => note.documentId == document.id);
    notifyListeners();
  }

  Future<Note> addNote({
    required String documentId,
    required int page,
    required double x,
    required double y,
    String text = '',
    String? colorLabelId,
  }) async {
    final now = DateTime.now();
    final note = Note(
      id: ShelfDatabase.newId(),
      documentId: documentId,
      page: page,
      x: Note.normalizeCoord(x),
      y: Note.normalizeCoord(y),
      text: text,
      colorLabelId: colorLabelId ?? defaultLabel.id,
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertNote(note);
    notes.insert(0, note);
    notifyListeners();
    return note;
  }

  Future<void> saveNote(Note note) async {
    final updated = note.copyWith(updatedAt: DateTime.now());
    await _db.upsertNote(updated);
    final index = notes.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      notes[index] = updated;
    } else {
      notes.insert(0, updated);
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await _db.deleteNote(id);
    notes.removeWhere((note) => note.id == id);
    notifyListeners();
  }

  Future<void> saveLabel(ColorLabel label) async {
    var next = label;
    if (label.isDefault) {
      for (var i = 0; i < labels.length; i++) {
        if (labels[i].id != label.id && labels[i].isDefault) {
          labels[i] = labels[i].copyWith(isDefault: false);
        }
      }
    }
    final index = labels.indexWhere((item) => item.id == label.id);
    if (index >= 0) {
      labels[index] = next;
    } else {
      labels.add(next);
    }
    labels.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    await _db.upsertLabel(next);
    notifyListeners();
  }

  Future<void> deleteLabel(ColorLabel label) async {
    if (labels.length <= 1) {
      lastError = 'Keep at least one colour label.';
      notifyListeners();
      return;
    }
    final fallback = labels.firstWhere(
      (item) => item.id != label.id && item.isDefault,
      orElse: () => labels.firstWhere((item) => item.id != label.id),
    );
    var promoted = fallback;
    if (label.isDefault && !fallback.isDefault) {
      promoted = fallback.copyWith(isDefault: true);
      await _db.upsertLabel(promoted);
    }
    await _db.deleteLabel(label.id, fallbackId: promoted.id);
    labels.removeWhere((item) => item.id == label.id);
    final fallbackIndex = labels.indexWhere((item) => item.id == promoted.id);
    if (fallbackIndex >= 0) {
      labels[fallbackIndex] = promoted;
    }
    for (var i = 0; i < notes.length; i++) {
      if (notes[i].colorLabelId == label.id) {
        notes[i] = notes[i].copyWith(colorLabelId: promoted.id);
      }
    }
    notifyListeners();
  }
}
