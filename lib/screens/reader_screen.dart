import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/shelf_store.dart';
import '../models/library_document.dart';
import '../models/note.dart';
import '../services/first_tap_tracker.dart';
import '../services/speech_capture.dart';
import '../theme/shelf_theme.dart';
import '../widgets/note_editor.dart';
import '../widgets/note_marker.dart';
import '../widgets/page_jump_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.store,
    required this.document,
    this.initialPage,
    this.focusNoteId,
  });

  final ShelfStore store;
  final LibraryDocument document;
  final int? initialPage;
  final String? focusNoteId;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _controller = PdfViewerController();
  final _taps = FirstTapTracker();
  final _speech = SpeechCapture();

  bool _showMarkers = true;
  int _page = 1;
  int _pageCount = 1;
  List<PdfOutlineNode> _outline = const [];
  String? _focusedNoteId;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage ?? 1;
    _pageCount = widget.document.pageCount ?? 1;
    _focusedNoteId = widget.focusNoteId;
    if (widget.focusNoteId != null) {
      _openNoteLater(widget.focusNoteId!);
    }
  }

  Future<void> _openNoteLater(String noteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      return;
    }
    final note = widget.store.notes.cast<Note?>().firstWhere(
      (item) => item?.id == noteId,
      orElse: () => null,
    );
    if (note != null) {
      await _editNote(note);
    }
  }

  Future<void> _onViewerReady(PdfDocument document, PdfViewerController controller) async {
    final outline = await document.loadOutline();
    if (!mounted) {
      return;
    }
    setState(() {
      _ready = true;
      _pageCount = document.pages.length;
      _outline = outline;
      _page = controller.pageNumber ?? _page;
    });
    await widget.store.updatePageCount(widget.document.id, document.pages.length);
    final target = widget.initialPage;
    if (target != null && target >= 1) {
      await controller.goToPage(pageNumber: target);
    }
  }

  Future<void> _createNoteAt(Offset globalPosition) async {
    if (!_controller.isReady) {
      return;
    }
    final local = _controller.globalToLocal(globalPosition);
    if (local == null) {
      return;
    }
    final hit = _controller.getPdfPageHitTestResult(
      local,
      useDocumentLayoutCoordinates: false,
    );
    if (hit == null || hit.page.width == 0 || hit.page.height == 0) {
      return;
    }
    final x = Note.normalizeCoord(hit.offset.x / hit.page.width);
    final y = Note.normalizeCoord(1 - (hit.offset.y / hit.page.height));
    final page = hit.page.pageNumber;

    final ready = await _speech.ensureReady();
    if (!mounted) {
      return;
    }
    final result = await NoteEditor.show(
      context,
      labels: widget.store.labels,
      defaultLabelId: widget.store.defaultLabel.id,
      speech: _speech,
      page: page,
      voiceHint: ready
          ? 'Orange is selected until you pick another colour.'
          : 'Voice dictation is limited on the Simulator. Type the note, or use a physical iPhone.',
    );
    if (result == null || result.delete || result.text.isEmpty) {
      return;
    }
    final note = await widget.store.addNote(
      documentId: widget.document.id,
      page: page,
      x: x,
      y: y,
      text: result.text,
      colorLabelId: result.colorLabelId,
    );
    if (mounted) {
      setState(() => _focusedNoteId = note.id);
    }
  }

  Future<void> _editNote(Note note) async {
    setState(() => _focusedNoteId = note.id);
    final result = await NoteEditor.show(
      context,
      labels: widget.store.labels,
      defaultLabelId: widget.store.defaultLabel.id,
      speech: _speech,
      note: note,
    );
    if (result == null) {
      return;
    }
    if (result.delete) {
      await widget.store.deleteNote(note.id);
      if (mounted) {
        setState(() {
          if (_focusedNoteId == note.id) {
            _focusedNoteId = null;
          }
        });
      }
      return;
    }
    await widget.store.saveNote(
      note.copyWith(text: result.text, colorLabelId: result.colorLabelId),
    );
  }

  Future<void> _goPage(int page) async {
    if (!_controller.isReady) {
      return;
    }
    final clamped = page.clamp(1, _pageCount);
    await _controller.goToPage(pageNumber: clamped);
    setState(() => _page = clamped);
  }

  void _showJump() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShelfColors.white,
      builder: (context) => PageJumpSheet(
        pageCount: _pageCount,
        currentPage: _page,
        outline: _outline,
        onJump: _goPage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        actions: [
          IconButton(
            tooltip: _showMarkers ? 'Hide markers' : 'Show markers',
            onPressed: () => setState(() => _showMarkers = !_showMarkers),
            icon: Icon(
              _showMarkers
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          return Listener(
            onPointerDown: (event) => _taps.recordDown(event.position),
            child: FutureBuilder<String>(
              future: widget.store.pdfPath(widget.document),
              builder: (context, snapshot) {
                final path = snapshot.data;
                if (path == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return PdfViewer.file(
                  path,
                  controller: _controller,
                  params: PdfViewerParams(
                    backgroundColor: ShelfColors.white,
                    onViewerReady: _onViewerReady,
                    onPageChanged: (page) {
                      if (page != null && mounted) {
                        setState(() => _page = page);
                      }
                    },
                    pageOverlaysBuilder: (context, pageRect, page) {
                      if (!_showMarkers) {
                        return const <Widget>[];
                      }
                      final pageNotes = widget.store.notesOnPage(
                        widget.document.id,
                        page.pageNumber,
                      );
                      return [
                        for (final note in pageNotes)
                          Positioned(
                            left: note.x * pageRect.width - 8,
                            top: note.y * pageRect.height - 8,
                            width: 22,
                            height: 22,
                            child: PdfOverlayInteractionRegion(
                              onTap: (_) {
                                _editNote(note);
                                return true;
                              },
                              child: NoteMarker(
                                color: widget.store
                                    .labelById(note.colorLabelId)
                                    .color,
                                focused: note.id == _focusedNoteId,
                              ),
                            ),
                          ),
                      ];
                    },
                    viewerOverlayBuilder: (context, size, handleLinkTap) {
                      return [
                        PdfOverlayInteractionRegion(
                          onDoubleTap: (details) {
                            final first = _taps.consumeFirstOr(
                              details.globalPosition,
                            );
                            _createNoteAt(first);
                            return true;
                          },
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                          ),
                        ),
                      ];
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: Material(
        color: ShelfColors.white,
        elevation: 0,
        child: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: ShelfColors.hairline)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page <= 1 ? null : () => _goPage(_page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _ready
                        ? 'Page $_page of $_pageCount'
                        : 'Opening PDF…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page >= _pageCount
                      ? null
                      : () => _goPage(_page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: 'Jump to page or chapter',
                  onPressed: _ready ? _showJump : null,
                  icon: const Icon(Icons.unfold_more),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
