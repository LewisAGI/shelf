import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

/// Grok-style preview of an export `.md` file. Share is the header icon.
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: ShelfMarkdownBody(data: markdown),
            ),
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
    final children = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('### ')) {
        children.add(_heading(line.substring(4), 15));
      } else if (line.startsWith('## ')) {
        children.add(_heading(line.substring(3), 18));
      } else if (line.startsWith('# ')) {
        children.add(_heading(line.substring(2), 22));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        children.add(_bullet(line.substring(2)));
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(
              TextSpan(children: _spans(line.trim())),
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.45,
                color: ShelfColors.ink,
              ),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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

  static final _inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');

  static List<InlineSpan> _spans(String input) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _inline.allMatches(input)) {
      if (match.start > start) {
        spans.add(TextSpan(text: input.substring(start, match.start)));
      }
      final bold = match.group(1);
      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13.5,
              backgroundColor: Color(0xFFF5F5F4),
            ),
          ),
        );
      }
      start = match.end;
    }
    if (start < input.length) {
      spans.add(TextSpan(text: input.substring(start)));
    }
    if (spans.isEmpty) {
      spans.add(const TextSpan(text: ''));
    }
    return spans;
  }
}
