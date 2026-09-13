import 'package:flutter/material.dart';

import '../models/color_label.dart';
import '../models/note.dart';
import '../services/filler_cleanup.dart';
import '../services/speech_capture.dart';
import '../theme/shelf_theme.dart';
import 'note_label_picker.dart';

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

  void _save() {
    Navigator.of(context).pop(
      NoteEditorResult(
        text: _controller.text.trim(),
        colorLabelId: _labelId,
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(
      NoteEditorResult(
        text: _controller.text,
        colorLabelId: _labelId,
        delete: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.note?.page ?? widget.page;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.note == null ? 'New note' : 'Note',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (page != null)
                Text(
                  'Page $page',
                  style: const TextStyle(color: ShelfColors.muted, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 10),
          NoteLabelPicker(
            labels: widget.labels,
            selectedId: _labelId,
            onSelected: (id) => setState(() => _labelId = id),
          ),
          const SizedBox(height: 10),
          _ChatComposer(
            controller: _controller,
            listening: _listening,
            onMic: _toggleListen,
          ),
          if (_status != null) ...[
            const SizedBox(height: 6),
            Text(
              _status!,
              style: const TextStyle(color: ShelfColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _manualClean,
                child: const Text('Clean up filler'),
              ),
              const Spacer(),
              if (widget.note != null)
                TextButton(
                  onPressed: _delete,
                  child: const Text('Delete'),
                ),
              FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grok-style chat composer: compact rounded field, mic in the corner.
class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.listening,
    required this.onMic,
  });

  final TextEditingController controller;
  final bool listening;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: listening ? ShelfColors.orange : ShelfColors.hairline,
          width: listening ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('note-composer-field'),
                controller: controller,
                minLines: 2,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16, height: 1.25),
                decoration: const InputDecoration(
                  hintText: 'Type or dictate a note…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _MicButton(listening: listening, onPressed: onMic),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onPressed});

  final bool listening;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: listening ? 'Stop listening' : 'Start a voice note',
      child: Material(
        color: listening ? ShelfColors.ink : ShelfColors.orange,
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('note-composer-mic'),
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              listening ? Icons.stop_rounded : Icons.mic,
              color: ShelfColors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
