import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/shelf_store.dart';
import '../models/library_document.dart';
import '../models/note.dart';
import '../models/note_selection.dart';
import '../services/note_open_sequence.dart';
import '../services/selection_anchor.dart';
import '../services/speech_capture.dart';
import '../theme/shelf_theme.dart';
import '../widgets/note_editor.dart';
import '../widgets/note_marker.dart';
import '../widgets/page_jump_sheet.dart';
import '../widgets/page_press_menu.dart';
import '../widgets/selection_comment_bar.dart';

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
  final _speech = SpeechCapture();

  bool _showMarkers = true;
  int _page = 1;
  int _pageCount = 1;
  List<PdfOutlineNode> _outline = const [];
  String? _focusedNoteId;
  bool _ready = false;
  final Completer<void> _viewerReady = Completer<void>();

  /// pdfrx selection stays off until the user picks **Select text**.
  bool _selectionEnabled = false;
  bool _hasActiveSelection = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage ?? 1;
    _pageCount = widget.document.pageCount ?? 1;
    _focusedNoteId = widget.focusNoteId;
    if (widget.focusNoteId != null) {
      unawaited(_openFocusedNote(widget.focusNoteId!));
    }
  }

  @override
  void dispose() {
    if (!_viewerReady.isCompleted) {
      _viewerReady.complete();
    }
    super.dispose();
  }

  Note? _noteById(String noteId) {
    return widget.store.notes.cast<Note?>().firstWhere(
      (item) => item?.id == noteId,
      orElse: () => null,
    );
  }

  /// Notes hub → reader: ready, then page, then marker, then editor.
  /// No fixed delay; the second tap is never used as a stand-in.
  Future<void> _openFocusedNote(String noteId) async {
    final targetPage = widget.initialPage ?? _noteById(noteId)?.page ?? _page;
    try {
      await NoteOpenSequence.run(
        waitUntilReady: () => _viewerReady.future,
        page: targetPage,
        goToPage: _goPage,
        waitUntilPageCurrent: () => _waitUntilPage(targetPage),
        ensureMarkerVisible: () async {
          final note = _noteById(noteId);
          if (note == null || !mounted) {
            return;
          }
          setState(() => _focusedNoteId = note.id);
          await _ensureMarkerVisible(note);
        },
        openNote: () async {
          final note = _noteById(noteId);
          if (note != null && mounted) {
            await _editNote(note);
          }
        },
        isActive: () => mounted,
      );
    } on Object {
      // Viewer never became ready, or the route was popped.
    }
  }

  Future<void> _waitUntilPage(int page) async {
    if ((_controller.pageNumber ?? _page) == page) {
      if (mounted && _page != page) {
        setState(() => _page = page);
      }
      if (mounted) {
        await WidgetsBinding.instance.endOfFrame;
      }
      return;
    }
    final done = Completer<void>();
    void tick() {
      if ((_controller.pageNumber ?? _page) == page && !done.isCompleted) {
        done.complete();
      }
    }

    _controller.addListener(tick);
    tick();
    try {
      await done.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } finally {
      _controller.removeListener(tick);
    }
    if (mounted && (_controller.pageNumber ?? _page) == page && _page != page) {
      setState(() => _page = page);
    }
    if (mounted) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _ensureMarkerVisible(Note note) async {
    if (!_controller.isReady) {
      return;
    }
    try {
      final page = _controller.pages.cast<PdfPage?>().firstWhere(
        (item) => item?.pageNumber == note.page,
        orElse: () => null,
      );
      if (page == null || page.width == 0 || page.height == 0) {
        return;
      }
      final bounds = markerPdfBounds(
        note: note,
        pageWidth: page.width,
        pageHeight: page.height,
      );
      final rect = _controller.calcRectForRectInsidePage(
        pageNumber: note.page,
        rect: PdfRect(bounds.left, bounds.top, bounds.right, bounds.bottom),
      );
      await _controller.ensureVisible(rect, margin: 32);
    } on Object {
      // Page camera APIs can fail before layout; the editor still opens
      // once the page is current.
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
    if (!_viewerReady.isCompleted) {
      _viewerReady.complete();
    }
    // Notes-hub focus owns goToPage so it cannot race the editor.
    if (widget.focusNoteId != null) {
      return;
    }
    final target = widget.initialPage;
    if (target != null && target >= 1) {
      await controller.goToPage(pageNumber: target);
    }
  }

  Note? _noteAt(Offset globalPosition) {
    if (!_controller.isReady) {
      return null;
    }
    final local = _controller.globalToLocal(globalPosition);
    if (local == null) {
      return null;
    }
    final hit = _controller.getPdfPageHitTestResult(
      local,
      useDocumentLayoutCoordinates: false,
    );
    if (hit == null || hit.page.width == 0 || hit.page.height == 0) {
      return null;
    }
    Size pageSizeInView;
    try {
      final layouts = _controller.layout.pageLayouts;
      final index = hit.page.pageNumber - 1;
      if (index < 0 || index >= layouts.length) {
        return null;
      }
      pageSizeInView = layouts[index].size;
    } on Object {
      return null;
    }
    final normalised = Offset(
      hit.offset.x / hit.page.width,
      1 - (hit.offset.y / hit.page.height),
    );
    for (final note in widget.store.notesOnPage(
      widget.document.id,
      hit.page.pageNumber,
    )) {
      if (noteMarkerContains(
        note: note,
        normalisedTap: normalised,
        pageSizeInView: pageSizeInView,
      )) {
        return note;
      }
    }
    return null;
  }

  /// Long-press on a marker edits it. Otherwise show Comment | Select text.
  bool _onPageLongPress(PdfOverlayInteractionDetails details) {
    final existing = _noteAt(details.globalPosition);
    if (existing != null) {
      unawaited(_editNote(existing));
      return true;
    }
    unawaited(_showPagePressMenu(details.globalPosition));
    return true;
  }

  Future<void> _showPagePressMenu(Offset globalPosition) async {
    if (!mounted) {
      return;
    }
    final action = await PagePressMenu.show(
      context,
      globalPosition: globalPosition,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case PagePressAction.comment:
        await _createNoteAt(globalPosition);
      case PagePressAction.selectText:
        await _beginSelectText(globalPosition);
    }
  }

  /// Re-enable pdfrx handles only after the menu, then select the word
  /// at the press point (not a free-drag grey box).
  Future<void> _beginSelectText(Offset globalPosition) async {
    setState(() {
      _selectionEnabled = true;
      _hasActiveSelection = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_controller.isReady) {
      return;
    }
    final documentPosition = _controller.globalToDocument(globalPosition);
    if (documentPosition == null) {
      return;
    }
    try {
      await _controller.textSelectionDelegate.selectWord(documentPosition);
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not grab text there. Drag a handle, or tap Done and Comment.',
          ),
        ),
      );
    }
  }

  Future<void> _exitSelectionMode() async {
    if (_controller.isReady) {
      try {
        await _controller.textSelectionDelegate.clearTextSelection();
      } on Object {
        // Clearing is best-effort; we still drop selection mode.
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionEnabled = false;
      _hasActiveSelection = false;
    });
  }

  Future<void> _onTextSelectionChange(PdfTextSelection selection) async {
    final text = await selection.getSelectedText();
    if (!mounted) {
      return;
    }
    setState(() => _hasActiveSelection = text.trim().isNotEmpty);
  }

  void _customizeSelectionMenu(
    PdfViewerContextMenuBuilderParams params,
    List<ContextMenuButtonItem> items,
  ) {
    items.removeWhere((item) => item.type == ContextMenuButtonType.selectAll);
    items.insert(
      0,
      ContextMenuButtonItem(
        label: 'Add comment',
        onPressed: () {
          ContextMenuController.removeAny();
          unawaited(_createNoteFromSelection());
        },
      ),
    );
  }

  Future<void> _createNoteAt(
    Offset globalPosition, {
    NoteSelection? selection,
  }) async {
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
    final x = selection?.anchorX ??
        Note.normalizeCoord(hit.offset.x / hit.page.width);
    final y = selection?.anchorY ??
        Note.normalizeCoord(1 - (hit.offset.y / hit.page.height));
    await _openComposer(
      page: hit.page.pageNumber,
      x: x,
      y: y,
      selection: selection,
    );
  }

  Future<void> _createNoteFromSelection() async {
    if (!_controller.isReady) {
      return;
    }
    final delegate = _controller.textSelectionDelegate;
    final text = await delegate.getSelectedText();
    final ranges = await delegate.getSelectedTextRanges();
    if (!mounted) {
      return;
    }
    if (ranges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a word first, then add a comment.'),
        ),
      );
      return;
    }
    final first = ranges.first;
    final page = _controller.pages.cast<PdfPage?>().firstWhere(
      (item) => item?.pageNumber == first.pageNumber,
      orElse: () => null,
    );
    if (page == null || page.width == 0 || page.height == 0) {
      return;
    }
    final selection = noteSelectionFromRanges(
      ranges: ranges,
      selectedText: text,
      pageWidth: page.width,
      pageHeight: page.height,
    );
    if (selection == null) {
      return;
    }
    await _openComposer(
      page: first.pageNumber,
      x: selection.anchorX,
      y: selection.anchorY,
      selection: selection,
    );
    await _exitSelectionMode();
  }

  Future<void> _openComposer({
    required int page,
    required double x,
    required double y,
    NoteSelection? selection,
  }) async {
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
      x: x,
      y: y,
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
      x: result.x,
      y: result.y,
      text: result.text,
      colorLabelId: result.colorLabelId,
      selection: selection,
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
      note.copyWith(
        text: result.text,
        colorLabelId: result.colorLabelId,
        x: result.x,
        y: result.y,
      ),
    );
  }

  Future<void> _goPage(int page) async {
    if (!_controller.isReady || !mounted) {
      return;
    }
    final clamped = page.clamp(1, _pageCount);
    await _controller.goToPage(pageNumber: clamped);
    if (mounted) {
      setState(() => _page = clamped);
    }
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
          return FutureBuilder<String>(
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
                  // Selection is off until Select text, so long-press is ours.
                  textSelectionParams: PdfTextSelectionParams(
                    enabled: _selectionEnabled,
                    enableSelectionHandles: true,
                    showContextMenuAutomatically: true,
                    onTextSelectionChange: _onTextSelectionChange,
                  ),
                  customizeContextMenuItems: _customizeSelectionMenu,
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
                      if (!_selectionEnabled)
                        PdfOverlayInteractionRegion(
                          onLongPress: _onPageLongPress,
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                          ),
                        ),
                      if (_selectionEnabled)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: SelectionCommentBar(
                            hasSelection: _hasActiveSelection,
                            onAddComment: () {
                              unawaited(_createNoteFromSelection());
                            },
                            onDone: () {
                              unawaited(_exitSelectionMode());
                            },
                          ),
                        ),
                    ];
                  },
                ),
              );
            },
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
