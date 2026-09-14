import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../models/color_label.dart';
import '../models/note.dart';
import '../services/ai_client.dart';
import '../services/notes_export.dart';
import '../services/pdf_section_resolver.dart';
import '../theme/shelf_theme.dart';
import 'ai_scope.dart';
import 'ai_send_scope.dart';

typedef PdfBytesLoader = Future<List<int>?> Function();

/// One in-app action: send the current note and/or selected page text
/// to the user's provider and show the reply.
class AskAboutNoteButton extends StatelessWidget {
  const AskAboutNoteButton({
    super.key,
    required this.noteText,
    this.selectedText,
    this.documentTitle,
    this.page,
    this.compact = false,
    this.hideWhenNoKey = false,
    this.offerPdf = false,
    this.loadPdf,
    this.pdfFileName,
    this.notes = const [],
    this.heading,
    this.subheading,
    this.sections = const [],
    this.note,
  });

  /// Read at tap time so the composer field is current.
  final String Function() noteText;
  final String? selectedText;
  final String? documentTitle;
  final int? page;
  final bool compact;

  /// Composer sheet: hide the control when the user has no key (they cannot
  /// see the snackbar behind the modal). Notes hub keeps the button.
  final bool hideWhenNoKey;
  final bool offerPdf;
  final PdfBytesLoader? loadPdf;
  final String? pdfFileName;
  final List<AiNoteSnippet> notes;
  final String? heading;
  final String? subheading;

  /// Current PDF outline (or page-title fallback). Used when [heading]
  /// is not passed explicitly.
  final List<PdfSection> sections;
  final Note? note;

  static AiAskRequest requestFor({
    required String noteText,
    String? selectedText,
    String? documentTitle,
    int? page,
    Note? note,
    List<AiNoteSnippet> notes = const [],
    List<int>? pdfBytes,
    String? pdfFileName,
    String? pdfSkippedReason,
    String? heading,
    String? subheading,
    List<PdfSection> sections = const [],
  }) {
    final resolved = _resolveHeadings(
      heading: heading,
      subheading: subheading,
      sections: sections,
      note: note,
      page: page,
    );
    return AiAskRequest(
      noteText: noteText.trim().isNotEmpty ? noteText : (note?.text ?? ''),
      selectedText: selectedText ?? note?.selection?.text,
      documentTitle: documentTitle,
      page: page ?? note?.page,
      heading: resolved.heading,
      subheading: resolved.subheading,
      notes: notes,
      pdfBytes: pdfBytes,
      pdfFileName: pdfFileName,
      pdfSkippedReason: pdfSkippedReason,
    );
  }

  static NoteHeadings _resolveHeadings({
    String? heading,
    String? subheading,
    List<PdfSection> sections = const [],
    Note? note,
    int? page,
  }) {
    if ((heading != null && heading.trim().isNotEmpty) ||
        (subheading != null && subheading.trim().isNotEmpty)) {
      return NoteHeadings(
        heading: heading?.trim().isEmpty == true ? null : heading?.trim(),
        subheading:
            subheading?.trim().isEmpty == true ? null : subheading?.trim(),
      );
    }
    if (note != null) {
      return PdfSectionResolver.forNote(note, sections);
    }
    if (page != null) {
      return PdfSectionResolver.headingsFor(sections: sections, page: page);
    }
    return const NoteHeadings();
  }

  static Future<void> open(
    BuildContext context, {
    required String noteText,
    String? selectedText,
    String? documentTitle,
    int? page,
    Note? note,
    List<AiNoteSnippet> notes = const [],
    bool offerPdf = false,
    PdfBytesLoader? loadPdf,
    String? pdfFileName,
    String? heading,
    String? subheading,
    List<PdfSection> sections = const [],
    Future<List<PdfSection>> Function()? loadSections,
    List<Note> notesToResolve = const [],
    ColorLabel Function(String id)? labelById,
  }) async {
    final ai = AiScope.maybeOf(context);
    if (ai == null || !ai.hasApiKey) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add your own API key in Settings. Shelf does not ship a house key.',
          ),
        ),
      );
      return;
    }
    final sectionsFuture = loadSections?.call();
    List<int>? pdfBytes;
    String? pdfSkippedReason;
    if (offerPdf && loadPdf != null) {
      final scope = await AiSendScopeDialog.show(context);
      if (!context.mounted || scope == null) {
        return;
      }
      if (scope == AiSendScope.includePdf) {
        if (!ai.provider.supportsPdfAttachment) {
          pdfSkippedReason = ai.provider.pdfUnsupportedReason;
        } else {
          pdfBytes = await loadPdf();
          if (pdfBytes == null || pdfBytes.isEmpty) {
            pdfSkippedReason = 'Could not read the PDF on this phone.';
            pdfBytes = null;
          }
        }
      }
    }
    var resolvedSections = sections;
    if (sectionsFuture != null) {
      try {
        resolvedSections = await sectionsFuture;
      } on Object {
        resolvedSections = const [];
      }
    }
    final resolvedNotes = notesToResolve.isNotEmpty && labelById != null
        ? NotesExport.snippets(
            notes: notesToResolve,
            labelById: labelById,
            outline: resolvedSections,
          )
        : notes;
    final request = requestFor(
      noteText: noteText,
      selectedText: selectedText,
      documentTitle: documentTitle,
      page: page,
      note: note,
      notes: resolvedNotes,
      pdfBytes: pdfBytes,
      pdfFileName: pdfFileName,
      pdfSkippedReason: pdfSkippedReason,
      heading: heading,
      subheading: subheading,
      sections: resolvedSections,
    );
    if (!request.hasAnythingToAsk) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a note or select text first.')),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    await AskAboutNoteSheet.show(
      context,
      ask: () => ai.askAbout(request),
    );
  }

  Future<void> _ask(BuildContext context) {
    return open(
      context,
      noteText: noteText(),
      selectedText: selectedText,
      documentTitle: documentTitle,
      page: page,
      note: note,
      notes: notes,
      offerPdf: offerPdf,
      loadPdf: loadPdf,
      pdfFileName: pdfFileName,
      heading: heading,
      subheading: subheading,
      sections: sections,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = AiScope.maybeOf(context);
    if (hideWhenNoKey && (ai == null || !ai.hasApiKey)) {
      return const SizedBox.shrink();
    }
    if (compact) {
      return TextButton(
        key: const Key('ask-about-note'),
        onPressed: () => _ask(context),
        child: const Text(
          'Ask about this note',
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return OutlinedButton.icon(
      key: const Key('ask-about-note'),
      onPressed: () => _ask(context),
      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
      label: const Text('Ask about this note'),
    );
  }
}

class AskAboutNoteSheet extends StatefulWidget {
  const AskAboutNoteSheet({super.key, required this.ask});

  final Future<AiAskOutcome> Function() ask;

  static Future<void> show(
    BuildContext context, {
    required Future<AiAskOutcome> Function() ask,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ShelfColors.white,
      builder: (context) => AskAboutNoteSheet(ask: ask),
    );
  }

  @override
  State<AskAboutNoteSheet> createState() => _AskAboutNoteSheetState();
}

class _AskAboutNoteSheetState extends State<AskAboutNoteSheet> {
  String? _reply;
  String? _error;
  String? _pdfNotice;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final outcome = await widget.ask();
      if (!mounted) {
        return;
      }
      setState(() {
        _reply = outcome.reply;
        _pdfNotice = outcome.pdfNotice;
        _loading = false;
      });
    } on AiClientException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not reach the provider.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ask about this note',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              key: const Key('ask-about-note-error'),
              _error!,
              style: const TextStyle(color: ShelfColors.muted, height: 1.4),
            )
          else ...[
            if (_pdfNotice != null) ...[
              Text(
                key: const Key('ask-about-note-pdf-notice'),
                'PDF not attached: $_pdfNotice',
                style: const TextStyle(color: ShelfColors.muted, height: 1.4),
              ),
              const SizedBox(height: 8),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Text(
                  key: const Key('ask-about-note-result'),
                  _reply ?? '',
                  style: const TextStyle(height: 1.45),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
