import 'package:flutter/material.dart';

import '../models/color_label.dart';
import '../models/note.dart';
import '../services/filler_cleanup.dart';
import '../services/speech_capture.dart';
import '../theme/shelf_theme.dart';
import 'colour_label_chip.dart';

class NoteEditorResult {
  const NoteEditorResult({
    required this.text,
    required this.colorLabelId,
    this.delete = false,
  });

  final String text;
  final String colorLabelId;
  final bool delete;
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.labels,
    required this.defaultLabelId,
    required this.speech,
    this.note,
    this.page,
    this.voiceHint,
  });

  final List<ColorLabel> labels;
  final String defaultLabelId;
  final SpeechCapture speech;
  final Note? note;
  final int? page;
  final String? voiceHint;

  static Future<NoteEditorResult?> show(
    BuildContext context, {
    required List<ColorLabel> labels,
    required String defaultLabelId,
    required SpeechCapture speech,
    Note? note,
    int? page,
    String? voiceHint,
  }) {
    return showModalBottomSheet<NoteEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShelfColors.white,
      builder: (context) {
        return NoteEditor(
          labels: labels,
          defaultLabelId: defaultLabelId,
          speech: speech,
          note: note,
          page: page,
          voiceHint: voiceHint,
        );
      },
    );
  }

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController _controller;
  late String _labelId;
  bool _listening = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note?.text ?? '');
    _labelId = widget.note?.colorLabelId ?? widget.defaultLabelId;
    _status = widget.voiceHint;
  }

  @override
  void dispose() {
    if (_listening) {
      widget.speech.stop();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await widget.speech.stop();
      setState(() => _listening = false);
      _autoClean();
      return;
    }

    final ready = await widget.speech.ensureReady();
    if (!ready) {
      setState(() {
        _status =
            widget.speech.unavailableReason ??
            'Voice dictation needs a physical iPhone. Type the note instead.';
      });
      return;
    }

    try {
      await widget.speech.start(
        onText: (words, finalResult) {
          if (!mounted) {
            return;
          }
          setState(() {
            _controller.text = words;
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
            if (finalResult) {
              _listening = false;
            }
          });
          if (finalResult) {
            _autoClean();
          }
        },
      );
      setState(() {
        _listening = true;
        _status = 'Listening… tap the microphone to stop.';
      });
    } on Object catch (error) {
      setState(() {
        _listening = false;
        _status = error.toString();
      });
    }
  }

  void _autoClean() {
    final cleaned = FillerCleanup.clean(_controller.text);
    if (cleaned != _controller.text) {
      setState(() {
        _controller.text = cleaned;
        _controller.selection = TextSelection.collapsed(offset: cleaned.length);
        _status = 'Filler words removed.';
      });
    }
  }

  void _manualClean() {
    final cleaned = FillerCleanup.clean(_controller.text);
    setState(() {
      _controller.text = cleaned;
      _controller.selection = TextSelection.collapsed(offset: cleaned.length);
      _status = cleaned.isEmpty
          ? 'Nothing left after cleanup.'
          : 'Filler words removed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.note?.page ?? widget.page;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.note == null ? 'New note' : 'Note',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (page != null)
              Text(
                'Page $page',
                style: const TextStyle(color: ShelfColors.muted),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in widget.labels)
                  ColourLabelChip(
                    label: label,
                    selected: label.id == _labelId,
                    onTap: () => setState(() => _labelId = label.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Dictate or type the note…',
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(
                _status!,
                style: const TextStyle(color: ShelfColors.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filled(
                  onPressed: _toggleListen,
                  style: IconButton.styleFrom(
                    backgroundColor: _listening
                        ? ShelfColors.ink
                        : ShelfColors.orange,
                    foregroundColor: ShelfColors.white,
                  ),
                  icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                  tooltip: _listening ? 'Stop listening' : 'Dictate',
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _manualClean,
                  child: const Text('Clean up filler'),
                ),
                const Spacer(),
                if (widget.note != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        NoteEditorResult(
                          text: _controller.text,
                          colorLabelId: _labelId,
                          delete: true,
                        ),
                      );
                    },
                    child: const Text('Delete'),
                  ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      NoteEditorResult(
                        text: _controller.text.trim(),
                        colorLabelId: _labelId,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
