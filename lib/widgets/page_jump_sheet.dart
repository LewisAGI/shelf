import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/shelf_theme.dart';

/// Chapters sheet: page jump stays, the list follows the Brink layout.
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

    final viewHeight = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final available = viewHeight - keyboard - 12;
    final preferred = viewHeight * 0.78;
    final sheetHeight = preferred < available ? preferred : available;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        key: const Key('chapters-sheet'),
        height: sheetHeight,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ShelfColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      'Chapters',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: ShelfColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Text(
              chapters.isEmpty
                  ? '${widget.pageCount} pages'
                  : '${chapters.length} ${chapters.length == 1 ? 'chapter' : 'chapters'}',
              style: const TextStyle(
                fontSize: 13,
                color: ShelfColors.muted,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chapters-page-field'),
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Page number',
                      ),
                      onSubmitted: (_) => _go(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('chapters-go'),
                    tooltip: 'Go to page',
                    onPressed: _go,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: chapters.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Text(
                        'No table of contents in this PDF.',
                        style: TextStyle(color: ShelfColors.muted, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final entry = chapters[index];
                        final destPage = entry.$2.dest?.pageNumber;
                        final isCurrent =
                            destPage != null && destPage == widget.currentPage;
                        final passed =
                            destPage != null && destPage < widget.currentPage;
                        final title = entry.$2.title.trim().isEmpty
                            ? 'Untitled chapter'
                            : entry.$2.title.trim();
                        return Padding(
                          padding: EdgeInsets.only(left: entry.$1 * 16),
                          child: Material(
                            color: isCurrent
                                ? ShelfColors.orangeSoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              key: Key('chapter-tile-$index'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: destPage == null ? null : () => _go(destPage),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? ShelfColors.orange
                                            : const Color(0xFFF5F5F4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isCurrent
                                              ? ShelfColors.white
                                              : ShelfColors.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.25,
                                              fontWeight: isCurrent
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: ShelfColors.ink,
                                            ),
                                          ),
                                          if (destPage != null)
                                            Text(
                                              'p. $destPage',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: ShelfColors.muted,
                                                height: 1.3,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrent)
                                      const Icon(
                                        Icons.check_circle,
                                        color: ShelfColors.orange,
                                        size: 20,
                                      )
                                    else if (passed)
                                      const Icon(
                                        Icons.check,
                                        color: ShelfColors.muted,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
