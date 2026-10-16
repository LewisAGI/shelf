import 'package:flutter/material.dart';

import '../data/shelf_store.dart';
import '../theme/shelf_theme.dart';
import 'library_screen.dart';
import 'notes_hub_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final ShelfStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _notesQuery = TextEditingController();

  @override
  void dispose() {
    _notesQuery.dispose();
    super.dispose();
  }

  void _openNotesForBook(String title) {
    _notesQuery
      ..text = title
      ..selection = TextSelection.collapsed(offset: title.length);
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          LibraryScreen(
            store: widget.store,
            onViewAllComments: _openNotesForBook,
          ),
          NotesHubScreen(
            store: widget.store,
            searchController: _notesQuery,
          ),
          SettingsScreen(store: widget.store),
        ],
      ),
      bottomNavigationBar: _ShelfNav(
        index: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _ShelfNav extends StatelessWidget {
  const _ShelfNav({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: Material(
            color: ShelfColors.white,
            elevation: 8,
            shadowColor: Colors.black26,
            shape: const StadiumBorder(
              side: BorderSide(color: ShelfColors.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavButton(
                    buttonKey: const Key('nav-library'),
                    tooltip: 'Library',
                    icon: Icons.menu_book_outlined,
                    selectedIcon: Icons.menu_book,
                    selected: index == 0,
                    onPressed: () => onSelected(0),
                  ),
                  _NavButton(
                    buttonKey: const Key('nav-notes'),
                    tooltip: 'Notes',
                    icon: Icons.sticky_note_2_outlined,
                    selectedIcon: Icons.sticky_note_2,
                    selected: index == 1,
                    onPressed: () => onSelected(1),
                  ),
                  _NavButton(
                    buttonKey: const Key('nav-settings'),
                    tooltip: 'Settings',
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    selected: index == 2,
                    onPressed: () => onSelected(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onPressed,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: buttonKey,
        onPressed: onPressed,
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? ShelfColors.orangeSoft : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            selected ? selectedIcon : icon,
            color: selected ? ShelfColors.orange : ShelfColors.muted,
            size: 22,
          ),
        ),
      ),
    );
  }
}
