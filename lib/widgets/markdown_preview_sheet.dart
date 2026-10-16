import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

/// Preview of notes plus the schema guide. Share is the header icon.
class MarkdownPreviewSheet extends StatelessWidget {
  const MarkdownPreviewSheet({
    super.key,
    required this.fileName,
    required this.markdown,
  });

  final String fileName;
  final String markdown;

  static Future<bool> show(
    BuildContext context, {
    required String fileName,
    required String markdown,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ShelfColors.white,
      builder: (context) {
        return MarkdownPreviewSheet(fileName: fileName, markdown: markdown);
      },
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;
    return SizedBox(
      key: const Key('markdown-preview-sheet'),
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  key: const Key('markdown-preview-close'),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    fileName,
                    key: const Key('markdown-preview-filename'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: ShelfColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('markdown-preview-share'),
                  tooltip: 'Share',
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.ios_share),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ShelfColors.hairline),
          Expanded(
            child: ShelfMarkdownBody(data: markdown),
          ),
        ],
      ),
    );
  }
}

/// Small markdown body: headings, bullets, bold, and inline code.
class ShelfMarkdownBody extends StatelessWidget {
  const ShelfMarkdownBody({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      itemCount: lines.length,
      itemBuilder: (context, index) => _line(lines[index]),
    );
  }

  Widget _line(String raw) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      return const SizedBox(height: 10);
    }
    final trimmed = line.trimLeft();
    if (trimmed.startsWith(r'\#') ||
        trimmed.startsWith(r'\- ') ||
        trimmed.startsWith(r'\* ')) {
      return _paragraph(line);
    }
    if (line.startsWith('### ')) {
      return _heading(line.substring(4), 15);
    }
    if (line.startsWith('## ')) {
      return _heading(line.substring(3), 18);
    }
    if (line.startsWith('# ')) {
      return _heading(line.substring(2), 22);
    }
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return _bullet(line.substring(2));
    }
    return _paragraph(line);
  }

  Widget _paragraph(String line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(children: _spans(line.trim())),
        style: const TextStyle(
          fontSize: 15.5,
          height: 1.45,
          color: ShelfColors.ink,
        ),
      ),
    );
  }

  Widget _heading(String text, double size) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text.rich(
        TextSpan(children: _spans(text.trim())),
        style: TextStyle(
          fontSize: size,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: size >= 20 ? -0.4 : -0.2,
          color: ShelfColors.ink,
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8, right: 10),
            child: Icon(Icons.circle, size: 5, color: ShelfColors.ink),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: _spans(text.trim())),
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.45,
                color: ShelfColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _codeStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13.5,
    backgroundColor: Color(0xFFF5F5F4),
  );

  static List<InlineSpan> _spans(String input) {
    final spans = <InlineSpan>[];
    final plain = StringBuffer();
    void flush() {
      if (plain.isEmpty) {
        return;
      }
      spans.add(TextSpan(text: plain.toString()));
      plain.clear();
    }

    var i = 0;
    while (i < input.length) {
      if (input.codeUnitAt(i) == 0x5c && i + 1 < input.length) {
        final next = input[i + 1];
        if (next == '\\' || next == '*' || next == '`' || next == '#' || next == '-') {
          plain.write(next);
          i += 2;
          continue;
        }
      }
      if (input.startsWith('**', i)) {
        final end = input.indexOf('**', i + 2);
        if (end != -1) {
          flush();
          spans.add(
            TextSpan(
              text: input.substring(i + 2, end),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
          i = end + 2;
          continue;
        }
      }
      if (input.startsWith('`', i)) {
        final end = input.indexOf('`', i + 1);
        if (end != -1) {
          flush();
          spans.add(
            TextSpan(
              text: input.substring(i + 1, end),
              style: _codeStyle,
            ),
          );
          i = end + 1;
          continue;
        }
      }
      plain.write(input[i]);
      i++;
    }
    flush();
    if (spans.isEmpty) {
      spans.add(const TextSpan(text: ''));
    }
    return spans;
  }
}
