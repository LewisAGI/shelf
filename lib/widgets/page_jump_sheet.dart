import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/shelf_theme.dart';

class PageJumpSheet extends StatefulWidget {
  const PageJumpSheet({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.outline,
    required this.onJump,
  });

  final int pageCount;
  final int currentPage;
  final List<PdfOutlineNode> outline;
  final ValueChanged<int> onJump;

  @override
  State<PageJumpSheet> createState() => _PageJumpSheetState();
}

class _PageJumpSheetState extends State<PageJumpSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentPage}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go([int? page]) {
    final parsed = page ?? int.tryParse(_controller.text.trim());
    if (parsed == null) {
      return;
    }
    final clamped = parsed.clamp(1, widget.pageCount);
    widget.onJump(clamped);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chapters = <(int depth, PdfOutlineNode node)>[];
    void walk(List<PdfOutlineNode> nodes, int depth) {
      for (final node in nodes) {
        chapters.add((depth, node));
        walk(node.children, depth + 1);
      }
    }

    walk(widget.outline, 0);

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
          Text('Jump to page', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'This document has ${widget.pageCount} pages.',
            style: const TextStyle(color: ShelfColors.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Page number',
                  ),
                  onSubmitted: (_) => _go(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _go, child: const Text('Go')),
            ],
          ),
          if (chapters.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Chapters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final entry = chapters[index];
                  final destPage = entry.$2.dest?.pageNumber;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(left: 12.0 + entry.$1 * 16),
                    title: Text(entry.$2.title.trim().isEmpty
                        ? 'Untitled chapter'
                        : entry.$2.title),
                    subtitle: destPage == null ? null : Text('Page $destPage'),
                    enabled: destPage != null,
                    onTap: destPage == null ? null : () => _go(destPage),
                  );
                },
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'No table of contents in this PDF.',
                style: TextStyle(color: ShelfColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
