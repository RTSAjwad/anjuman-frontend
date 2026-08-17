import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/auth_provider.dart';
import '../providers/browser_provider.dart';
import '../providers/card_store.dart';
import '../providers/deck_provider.dart';
import '../providers/note_provider.dart';
import '../providers/note_store.dart';
import '../models/card_record.dart';
import '../models/deck.dart';
import '../models/note_record.dart';
import '../widgets/deck_tree.dart';
import '../widgets/drawer_context.dart';
import '../widgets/narrow_app_bar.dart';
import '../widgets/responsive_dialog.dart';
import '../widgets/card_html_view.dart';
import '../config/breakpoints.dart';
import 'deck_detail_screen.dart';

sealed class FilterNode {
  const FilterNode();
}

class DeckFilterNode extends FilterNode {
  final DeckResponse deck;
  const DeckFilterNode(this.deck);
}

class StateFilterNode extends FilterNode {
  final String state;
  const StateFilterNode(this.state);
}

class NoteTypeFilterNode extends FilterNode {
  final NoteType noteType;
  const NoteTypeFilterNode(this.noteType);
}

class FlagFilterNode extends FilterNode {
  final int flag;
  const FlagFilterNode(this.flag);
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _tableScrollController = ScrollController();
  final ResizableTableController _tableController = ResizableTableController(
    defaultColumnWidth: 150,
    defaultRowHeight: 40,
    defaultHeightConstraint: const ConstrainedTableSize(min: 40),
    defaultWidthConstraint: const ConstrainedTableSize(min: 80),
  );
  bool _fetchingMore = false;

  List<String> _columns = ['Sort Field', 'Deck'];
  List<String> _sortFields = ['question', 'deck'];
  String _activeSort = 'created_at';
  bool _sortAsc = false;

  List<TreeNode<FilterNode>> _filterNodes = [];

  int? _selectedCardIndex;
  int _activeTab = 0; // 0 = Cards, 1 = Notes
  int? _lastTargetDeckId;
  _CompactView _compactView = _CompactView.table;
  CardRecord? get _selectedCard {
    if (_selectedCardIndex == null) return null;
    final cards = context.read<BrowserProvider>().cards;
    if (_selectedCardIndex! >= cards.length) return null;
    return cards[_selectedCardIndex!];
  }

  List<CardRecord> get _selectedNoteCards {
    final card = _selectedCard;
    if (card == null) return [];
    final cards = context.read<BrowserProvider>().cards;
    return cards.where((c) => c.noteId == card.noteId).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _filterNodes = [
      TreeItemNode<FilterNode>(
        data: const StateFilterNode('root'),
        expanded: true,
        children: [
          TreeItemNode(data: const StateFilterNode('new'), children: []),
          TreeItemNode(data: const StateFilterNode('learning'), children: []),
          TreeItemNode(data: const StateFilterNode('review'), children: []),
          TreeItemNode(data: const StateFilterNode('relearning'), children: []),
          TreeItemNode(data: const StateFilterNode('due'), children: []),
        ],
      ),
      TreeItemNode<FilterNode>(
        data: const FlagFilterNode(0),
        expanded: true,
        children: [
          for (var i = 1; i <= 7; i++)
            TreeItemNode(data: FlagFilterNode(i), children: []),
        ],
      ),
    ];
    final deckProvider = context.read<DeckProvider>();
    deckProvider.addListener(_onDecksChanged);
    deckProvider.addListener(_onNoteTypesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deckParam = GoRouterState.of(context).uri.queryParameters['deck'];
      if (deckParam != null) {
        final deckId = int.tryParse(deckParam);
        if (deckId != null) {
          context.read<BrowserProvider>().setDeckIds([deckId]);
        }
      } else {
        context.read<BrowserProvider>().loadCards();
      }
      deckProvider.loadDecks();
      deckProvider.loadNoteTypes();
      deckProvider.loadDecks();
    });
  }

  void _onDecksChanged() {
    _rebuildDeckTree();
  }

  void _rebuildDeckTree() {
    final decks = context.read<DeckProvider>().decks;
    if (decks.isEmpty) return;
    final selectedIds = context.read<BrowserProvider>().deckIds.toSet();
    setState(() {
      var root = _buildDeckTree(decks);
      for (final id in selectedIds) {
        root = _selectDeckInTree(root, id);
      }
      _replaceOrAddSection('decks', root);
    });
  }

  TreeItemNode<FilterNode> _selectDeckInTree(
      TreeItemNode<FilterNode> node, int deckId) {
    return _selectDeckInTreeInternal(node, deckId).node;
  }

  ({TreeItemNode<FilterNode> node, bool found}) _selectDeckInTreeInternal(
      TreeItemNode<FilterNode> node, int deckId) {
    var foundInSubtree = false;
    final newChildren = <TreeNode<FilterNode>>[];
    for (final child in node.children) {
      if (child is TreeItemNode<FilterNode>) {
        final data = child.data;
        if (data is DeckFilterNode && data.deck.id == deckId) {
          newChildren.add(TreeItemNode<FilterNode>(
            data: data,
            selected: true,
            children: child.children,
            expanded: child.expanded,
          ));
          foundInSubtree = true;
        } else {
          final result = _selectDeckInTreeInternal(child, deckId);
          newChildren.add(result.node);
          if (result.found) {
            foundInSubtree = true;
          }
        }
      } else {
        newChildren.add(child);
      }
    }
    return (
      node: TreeItemNode<FilterNode>(
        data: node.data,
        expanded: foundInSubtree || node.expanded,
        children: newChildren,
        selected: node.selected,
      ),
      found: foundInSubtree,
    );
  }

  TreeItemNode<FilterNode> _buildDeckTree(List<DeckResponse> decks) {
    final root = buildDeckTree(decks);
    List<TreeNode<FilterNode>> convert(List<DeckNode> nodes) {
      return nodes
          .map((n) => TreeItemNode<FilterNode>(
                data: DeckFilterNode(n.deck),
                children: convert(n.children),
              ))
          .toList();
    }

    return TreeItemNode<FilterNode>(
      data: DeckFilterNode(DeckResponse(
        id: -1,
        schoolId: 0,
        title: 'Decks',
        createdBy: 0,
        createdAt: DateTime.now(),
      )),
      expanded: true,
      children: convert(root),
    );
  }

  void _onNoteTypesChanged() {
    final noteTypes = context.read<DeckProvider>().noteTypes;
    if (noteTypes.isEmpty) return;
    setState(() {
      final ntChildren = noteTypes
          .map((nt) => TreeItemNode<FilterNode>(
                data: NoteTypeFilterNode(nt),
                children: [],
              ))
          .toList();
      final root = TreeItemNode<FilterNode>(
        data: NoteTypeFilterNode(NoteType(
          id: -1,
          name: 'Note Type',
          fieldNames: [],
          sortField: '',
          templates: [],
          noteCount: 0,
        )),
        expanded: true,
        children: ntChildren,
      );
      _replaceOrAddSection('noteTypes', root);
    });
  }

  void _replaceOrAddSection(String key, TreeItemNode<FilterNode> node) {
    final idx = _filterNodes.indexWhere((n) {
      if (n is! TreeItemNode<FilterNode>) return false;
      return _sectionKey(n.data) == key;
    });
    if (idx >= 0) {
      _filterNodes = List.from(_filterNodes)..[idx] = node;
    } else {
      _filterNodes = [..._filterNodes, node];
    }
  }

  String? _sectionKey(FilterNode data) {
    if (data is DeckFilterNode && data.deck.id == -1) return 'decks';
    if (data is StateFilterNode && data.state == 'root') return 'states';
    if (data is NoteTypeFilterNode && data.noteType.id == -1) {
      return 'noteTypes';
    }
    if (data is FlagFilterNode && data.flag == 0) return 'flags';
    return null;
  }

  bool _isSectionRoot(FilterNode data) => _sectionKey(data) != null;

  String _sectionLabel(FilterNode data) {
    if (data is DeckFilterNode) return data.deck.title;
    if (data is StateFilterNode) return _stateLabel(data.state);
    if (data is NoteTypeFilterNode) return data.noteType.name;
    if (data is FlagFilterNode) return _flagLabel(data.flag);
    return '';
  }

  static const _flagColors = {
    1: Color(0xFFE53935),
    2: Color(0xFFF57C00),
    3: Color(0xFF43A047),
    4: Color(0xFF1E88E5),
    5: Color(0xFFD81B60),
    6: Color(0xFF00BCD4),
    7: Color(0xFF8E24AA),
  };

  String _flagLabel(int flag) {
    if (flag == 0) return 'Flags';
    const labels = {
      1: 'Red',
      2: 'Orange',
      3: 'Green',
      4: 'Blue',
      5: 'Pink',
      6: 'Turquoise',
      7: 'Purple',
    };
    return labels[flag] ?? 'Flag $flag';
  }

  void _syncAllFilters(List<TreeNode<FilterNode>> nodes) {
    final deckIds = <int>[];
    final states = <String>[];
    final noteTypeIds = <int>[];
    final flags = <int>[];
    _walkSelected(nodes, deckIds, states, noteTypeIds, flags);
    context.read<BrowserProvider>().setFilters(
          deckIds: deckIds,
          states: states,
          noteTypeIds: noteTypeIds,
          flags: flags,
        );
  }

  void _walkSelected(
    List<TreeNode<FilterNode>> nodes,
    List<int> deckIds,
    List<String> states,
    List<int> noteTypeIds,
    List<int> flags,
  ) {
    for (final node in nodes) {
      if (node is TreeItemNode<FilterNode> && node.selected) {
        final data = node.data;
        if (data is DeckFilterNode && data.deck.id != -1) {
          deckIds.add(data.deck.id);
        } else if (data is StateFilterNode && data.state != 'root') {
          states.add(data.state);
        } else if (data is NoteTypeFilterNode && data.noteType.id != -1) {
          noteTypeIds.add(data.noteType.id);
        } else if (data is FlagFilterNode && data.flag != 0) {
          flags.add(data.flag);
        }
      }
      _walkSelected(node.children, deckIds, states, noteTypeIds, flags);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final role = context.read<AuthProvider>().role;
    final isTeacher = role == 'teacher' || role == 'admin';
    if (isTeacher) {
      _columns = ['Sort Field', 'Deck'];
      _sortFields = ['question', 'deck'];
    } else {
      _columns = ['Sort Field', 'State', 'Due', 'Flag', 'Deck'];
      _sortFields = ['question', '', 'due_at', '', 'deck'];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tableScrollController.dispose();
    _tableController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<BrowserProvider>();
    if (_fetchingMore || !provider.hasNextPage || provider.isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchingMore = true;
      provider.nextPage().then((_) {
        _fetchingMore = false;
      });
    }
  }

  void _onTabChanged(int index) {
    if (index == _activeTab) return;
    setState(() {
      _activeTab = index;
    });
    // Reset scroll positions so pagination and layout start fresh for the
    // newly selected tab.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (_tableScrollController.hasClients) {
      _tableScrollController.jumpTo(0);
    }
    _fetchingMore = false;
  }

  void _onSearch(String value) {
    context.read<BrowserProvider>().setQuery(value);
  }

  void _onSort(int index) {
    final field = _sortFields[index];
    if (field.isEmpty) return;
    if (_activeSort == field) {
      _sortAsc = !_sortAsc;
    } else {
      _activeSort = field;
      _sortAsc = true;
    }
    final order = _sortAsc ? '' : '-';
    context.read<BrowserProvider>().setSort('$order$field');
  }

  TableCell _buildFlagCell(CardRecord card, {VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    final flagColor =
        card.flag != null && card.flag! > 0 ? _flagColors[card.flag] : null;
    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: colors.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.center,
          child: flagColor != null
              ? Icon(LucideIcons.flag, size: 14, color: flagColor)
              : const SizedBox(width: 14),
        ),
      ),
    );
  }

  TableCell _buildCell(String text,
      {bool alignRight = false, VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: colors.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(text, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  TableCell _buildHeader(
      ColorScheme colors, int index, bool active, String label) {
    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: colors.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onSort(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: active ? colors.primary : colors.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (active)
                Icon(
                  _sortAsc ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                  size: 14,
                  color: colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _buildCardRows(BrowserProvider provider, ColorScheme colors,
      bool isTeacher, List<TableRow> rows) {
    for (var i = 0; i < provider.cards.length; i++) {
      final card = provider.cards[i];
      final frontText = card.front
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final onTap = () {
        setState(() {
          if (_selectedCardIndex == i) {
            _selectedCardIndex = null;
          } else {
            _selectedCardIndex = i;
            _compactView = _CompactView.detail;
          }
        });
      };

      if (isTeacher) {
        rows.add(TableRow(cells: [
          _buildCell(frontText, onTap: onTap),
          _buildCell(card.deckTitle, onTap: onTap),
        ]));
      } else {
        rows.add(TableRow(cells: [
          _buildCell(frontText, onTap: onTap),
          _buildStateCell(card, onTap: onTap),
          _buildDueCell(card, onTap: onTap),
          _buildFlagCell(card, onTap: onTap),
          _buildCell(card.deckTitle, onTap: onTap),
        ]));
      }
    }
  }

  void _buildNoteRows(BrowserProvider provider, ColorScheme colors,
      bool isTeacher, List<TableRow> rows) {
    final noteStore = context.read<NoteStore>();
    // Preserve the order notes appear in the card list while de-duplicating
    // by noteId.
    final seen = <int>{};
    final noteIds = <int>[];
    for (final card in provider.cards) {
      if (seen.add(card.noteId)) noteIds.add(card.noteId);
    }

    for (var i = 0; i < noteIds.length; i++) {
      final noteId = noteIds[i];
      final note = noteStore.note(noteId);
      final noteCards =
          provider.cards.where((c) => c.noteId == noteId).toList();
      final firstCard = noteCards.first;

      // Sort field: prefer a human-readable fallback from the note's fields,
      // otherwise the first card's front (same as before).
      final sortField = _noteSortField(note, firstCard);

      // Card index within provider.cards for selection (used by detail pane).
      final cardIndex = provider.cards.indexWhere((c) => c.noteId == noteId);
      final onTap = () {
        setState(() {
          if (_selectedCardIndex == cardIndex) {
            _selectedCardIndex = null;
          } else {
            _selectedCardIndex = cardIndex;
            _compactView = _CompactView.detail;
          }
        });
      };

      final cardCount = note?.cardIds.length ?? noteCards.length;
      final cardsLabel = '$cardCount card${cardCount == 1 ? '' : 's'}';
      final noteTypeName = note?.noteTypeName ?? firstCard.noteTypeName;
      final deckTitle = firstCard.deckTitle;

      if (isTeacher) {
        rows.add(TableRow(cells: [
          _buildCell(sortField, onTap: onTap),
          _buildCell(cardsLabel, onTap: onTap),
          _buildCell(noteTypeName, onTap: onTap),
        ]));
      } else {
        rows.add(TableRow(cells: [
          _buildCell(sortField, onTap: onTap),
          _buildCell(cardsLabel, onTap: onTap),
          _buildCell(noteTypeName, onTap: onTap),
          _buildCell(deckTitle, onTap: onTap),
        ]));
      }
    }
  }

  String _noteSortField(NoteRecord? note, CardRecord firstCard) {
    if (note != null && note.fields.isNotEmpty) {
      final first = note.fields.values.first;
      final text = first?.toString().replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return firstCard.front.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final deckParam = GoRouterState.of(context).uri.queryParameters['deck'];
    final targetDeckId = deckParam != null ? int.tryParse(deckParam) : null;
    if (targetDeckId != null && _lastTargetDeckId != targetDeckId) {
      _lastTargetDeckId = targetDeckId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<BrowserProvider>().setDeckIds([targetDeckId]);
          _rebuildDeckTree();
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.of(context).size.width;
        final isCompact = width < Breakpoints.expanded;

        return Scaffold(
          child: Column(
            children: [
              _buildAppBar(colors, isCompact),
              const Divider(),
              Expanded(
                child: isCompact
                    ? _buildCompactContent(colors)
                    : _buildDesktopContent(colors),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(ColorScheme colors, bool isCompact) {
    if (isCompact) {
      final width = MediaQuery.of(context).size.width;
      final isNarrow = width < Breakpoints.medium;
      if (_compactView == _CompactView.table) {
        if (isNarrow) {
          return NarrowAppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Browser'),
                Consumer<BrowserProvider>(
                  builder: (context, provider, _) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: OutlineBadge(
                        child: Text('${provider.total} selected'),
                      ),
                    );
                  },
                ),
              ],
            ),
            trailing: _buildAppBarActions(colors),
          );
        }
        return AppBar(
          leading: [
            IconButton.outline(
              icon: const Icon(LucideIcons.menu, size: 20),
              onPressed: () => DrawerContext.of(context)?.call(),
            ),
          ],
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Browser'),
              Consumer<BrowserProvider>(
                builder: (context, provider, _) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: OutlineBadge(
                      child: Text('${provider.total} selected'),
                    ),
                  );
                },
              ),
            ],
          ),
          trailing: _buildAppBarActions(colors),
        );
      }

      return AppBar(
        title: const Text('Details'),
        leading: [
          IconButton.outline(
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
            onPressed: () => setState(() => _compactView = _CompactView.table),
          ),
        ],
        trailing: _buildAppBarActions(colors),
      );
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Browser'),
          Consumer<BrowserProvider>(
            builder: (context, provider, _) {
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: OutlineBadge(
                  child: Text(
                      '${provider.total} card${provider.total == 1 ? '' : 's'} selected'),
                ),
              );
            },
          ),
        ],
      ),
      trailing: _buildAppBarActions(colors),
    );
  }

  List<Widget> _buildAppBarActions(ColorScheme colors) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < Breakpoints.medium;
    final isCompact = width < Breakpoints.expanded;
    final actions = <Widget>[
      if (isNarrow && _compactView == _CompactView.table)
        IconButton.outline(
          icon: const Icon(LucideIcons.filter, size: 20),
          onPressed: () => _showFilterDrawer(),
        ),
      if (!isNarrow && (!isCompact || _compactView == _CompactView.table))
        Tabs(
          index: _activeTab,
          onChanged: _onTabChanged,
          children: const [
            TabItem(child: Text('Cards')),
            TabItem(child: Text('Notes')),
          ],
        ),
      if (!isNarrow && isCompact && _compactView == _CompactView.table)
        IconButton.outline(
          icon: const Icon(LucideIcons.filter, size: 20),
          onPressed: () => _showFilterDrawer(),
        ),
      IconButton.outline(
        icon: const Icon(LucideIcons.refreshCw, size: 20),
        onPressed: () => context.read<BrowserProvider>().loadCards(),
      ),
    ];
    return actions;
  }

  Widget _buildCompactContent(ColorScheme colors) {
    switch (_compactView) {
      case _CompactView.table:
        return Column(
          children: [
            _FilterBar(
              searchController: _searchController,
              onSearch: _onSearch,
            ),
            Expanded(child: _buildTableContent(colors)),
          ],
        );
      case _CompactView.detail:
        return _buildCardDetailPane();
    }
  }

  void _showFilterDrawer() {
    showOverlay(
      context,
      DrawerConfiguration(
        position: OverlayPosition.bottom,
        expands: false,
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                title: const Text('Filters'),
                trailing: [
                  Tabs(
                    index: _activeTab,
                    onChanged: _onTabChanged,
                    children: const [
                      TabItem(child: Text('Cards')),
                      TabItem(child: Text('Notes')),
                    ],
                  ),
                  IconButton.outline(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => closeOverlay(ctx),
                  ),
                ],
              ),
              Expanded(child: _buildFilterTree()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(ColorScheme colors) {
    final selectedCard = _selectedCard;
    final isLoading = context.watch<BrowserProvider>().isLoading;

    // Keep the pane count stable. Removing/adding a third ResizablePane on
    // selection makes the shadcn ResizablePanel reuse elements by position
    // (the panes carry no keys), which prevents the detail pane from
    // refreshing. Instead we always render all three panes and swap the
    // detail pane's contents, keyed on the selected card so it updates.
    return ResizablePanel.horizontal(
      draggerBuilder: (context) {
        return const HorizontalResizableDragger();
      },
      children: [
        ResizablePane(
          initialSize: 220,
          minSize: 160,
          child: _buildFilterTree(),
        ),
        ResizablePane.flex(
          child: Column(
            children: [
              _FilterBar(
                searchController: _searchController,
                onSearch: _onSearch,
              ),
              Expanded(child: _buildTableContent(colors)),
            ],
          ),
        ),
        ResizablePane.flex(
          child: selectedCard == null || isLoading
              ? const Center(child: Text('Select an item to view details'))
              : KeyedSubtree(
                  key: ValueKey<int>(selectedCard.cardId),
                  child: _buildCardDetailPane(),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterTree() {
    if (_filterNodes.length <= 1) {
      return const Center(child: CircularProgressIndicator());
    }
    return Theme(
      data: Theme.of(context).copyWith(radius: () => 0),
      child: Tree<FilterNode>(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        allowMultiSelect: true,
        nodes: _filterNodes,
        branchLine: BranchLine.line,
        onSelectionChanged: Tree.defaultSelectionHandler(
          _filterNodes,
          (value) {
            setState(() {
              _filterNodes = value;
              _syncAllFilters(value);
            });
          },
        ),
        builder: (context, node) {
          final data = node.data;
          final isSection = _isSectionRoot(data);
          final hasChildren = node.children.isNotEmpty;
          return TreeItem(
            onPressed: (isSection || hasChildren) ? null : () {},
            onExpand: (isSection || hasChildren)
                ? Tree.defaultItemExpandHandler(
                    _filterNodes,
                    node,
                    (value) {
                      setState(() => _filterNodes = value);
                    },
                  )
                : null,
            leading: data is FlagFilterNode && data.flag != 0
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      LucideIcons.flag,
                      size: 14,
                      color: _flagColors[data.flag],
                    ),
                  )
                : null,
            child: Text(
              _sectionLabel(data),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableContent(ColorScheme colors) {
    return Consumer2<BrowserProvider, CardStore>(
      builder: (context, provider, store, _) {
        // Watching CardStore makes the table (and its per-cell views) rebuild
        // whenever any card state changes from any screen, so reschedules etc.
        // reflect immediately without re-fetching.
        if (provider.isLoading && provider.cards.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.cards.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Failed to load cards'),
                const SizedBox(height: 8),
                Text(provider.error!,
                    style:
                        TextStyle(color: colors.mutedForeground, fontSize: 13)),
                const SizedBox(height: 16),
                Button.secondary(
                  onPressed: () => provider.loadCards(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.cards.isEmpty) {
          return const Center(child: Text('Nothing found'));
        }

        final headerCells = <TableCell>[];
        if (_activeTab == 0) {
          for (var i = 0; i < _columns.length; i++) {
            final active = _activeSort == _sortFields[i];
            headerCells.add(_buildHeader(colors, i, active, _columns[i]));
          }
        } else {
          headerCells.add(_buildHeader(colors, 0, false, 'Sort Field'));
          headerCells.add(_buildHeader(colors, 1, false, 'Cards'));
          headerCells.add(_buildHeader(colors, 2, false, 'Note Type'));
        }

        final rows = <TableRow>[
          TableHeader(cells: headerCells),
        ];

        final role = context.read<AuthProvider>().role;
        final isTeacher = role == 'teacher' || role == 'admin';

        if (_activeTab == 0) {
          _buildCardRows(provider, colors, isTeacher, rows);
        } else {
          _buildNoteRows(provider, colors, isTeacher, rows);
        }

        return Stack(
          children: [
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Scrollbar(
                      controller: _tableScrollController,
                      thumbVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        controller: _tableScrollController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
                          child: ResizableTable(
                            // No verticalController/horizontalController:
                            // passing them makes shadcn use its buggy
                            // ScrollableClient 2D viewport (crashes on
                            // resize/rebuild). Without them the table renders
                            // plain and the parent SingleChildScrollViews
                            // provide 1D scrolling.
                            controller: _tableController,
                            rows: rows,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }

  void _showEditNoteDialog(CardRecord card) {
    final deckProvider = context.read<DeckProvider>();
    final noteProvider = context.read<NoteProvider>();
    final noteStore = context.read<NoteStore>();
    final noteCards = _selectedNoteCards;
    final existing = noteStore.note(card.noteId) ??
        NoteRecord(
          noteId: card.noteId,
          // Fallback should be rare now: the browse projection carries
          // note_type_id, so NoteStore is normally populated on load.
          noteTypeId: 0,
          noteTypeName: card.noteTypeName,
          fields: card.fields,
          cardIds: noteCards.map((c) => c.cardId).toList(),
        );
    showResponsiveDialog(
      context,
      builder: (ctx, _) => NoteFormDialog(
        deckId: card.deckId,
        deckProvider: deckProvider,
        noteProvider: noteProvider,
        existingNote: existing,
        onSuccess: () {
          safeCloseOverlay(ctx);
          context.read<BrowserProvider>().loadCards();
        },
      ),
    );
  }

  /// Opens the card/note actions dropdown. [includeNote] controls whether the
  /// note-level entries (bury note / suspend note) are shown.
  ///
  /// Card-level suspend/bury are rendered as checkable toggles only when the
  /// card carries study state (student view); teachers/admins get `null` for
  /// these fields and see no card-level toggle.
  void _showCardActionsMenu(BuildContext context, CardRecord card,
      {required bool includeNote}) {
    final browser = context.read<BrowserProvider>();
    final cardStore = context.read<CardStore>();
    final role = context.read<AuthProvider>().role;
    final isStudent = role == 'student';

    showDropdown(
      context: context,
      builder: (context) {
        // Read suspend/bury from the shared CardStore (single source of
        // truth).
        final suspended = cardStore.isSuspended(card.cardId);
        final buried = cardStore.isBuried(card.cardId);

        return DropdownMenu(
          children: [
            if (isStudent)
              MenuCheckbox(
                value: buried,
                onChanged: (context, value) {
                  value
                      ? browser.buryCard(card.cardId)
                      : browser.unburyCard(card.cardId);
                },
                child: const Text('Bury card'),
              ),
            if (isStudent)
              MenuCheckbox(
                value: suspended,
                onChanged: (context, value) {
                  value
                      ? browser.suspendCard(card.cardId)
                      : browser.unsuspendCard(card.cardId);
                },
                child: const Text('Suspend card'),
              ),
            if (isStudent)
              MenuButton(
                leading: const Icon(LucideIcons.calendar, size: 16),
                onPressed: (_) => _showRescheduleDialog(context, card),
                child: const Text('Reschedule card'),
              ),
            if (includeNote) ...[
              if (isStudent) const MenuDivider(),
              MenuButton(
                leading: const Icon(LucideIcons.calendarOff, size: 16),
                onPressed: (_) => browser.buryNote(card.noteId),
                child: const Text('Bury note'),
              ),
              MenuButton(
                leading: const Icon(LucideIcons.ban, size: 16),
                onPressed: (_) => browser.suspendNote(card.noteId),
                child: const Text('Suspend note'),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showRescheduleDialog(BuildContext context, CardRecord card) {
    final controller = TextEditingController();
    final browser = context.read<BrowserProvider>();
    showResponsiveDialog(
      context,
      builder: (ctx, _) => AlertDialog(
        title: const Text('Reschedule card'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Days from now', style: TextStyle(fontSize: 13))
                  .semiBold(),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                placeholder: const Text('e.g. 3'),
                initialValue: '',
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          Button.ghost(
            onPressed: () => closeOverlay(ctx),
            child: const Text('Cancel'),
          ),
          Button.primary(
            onPressed: () {
              final days = int.tryParse(controller.text.trim());
              if (days == null) return;
              browser.rescheduleCard(card.cardId, days);
              closeOverlay(ctx);
            },
            child: const Text('Reschedule'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDetailPane() {
    final card = _selectedCard;
    if (card == null) {
      return const Center(child: Text('Select an item to view details'));
    }

    if (_activeTab == 0) {
      return _buildCardDetail(card);
    } else {
      return _buildNoteDetail(card);
    }
  }

  Widget _buildCardDetail(CardRecord card) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Card Details'),
          trailing: [
            IconButton.outline(
              icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
              onPressed: () =>
                  _showCardActionsMenu(context, card, includeNote: true),
            ),
            IconButton.outline(
              icon: const Icon(LucideIcons.pencil, size: 20),
              onPressed: () => _showEditNoteDialog(card),
            ),
            IconButton.outline(
              icon: const Icon(LucideIcons.x, size: 20),
              onPressed: () => setState(() => _selectedCardIndex = null),
            ),
          ],
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Front', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: colors.muted.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: CardHtmlView(html: card.front),
            ),
            const SizedBox(height: 16),
            const Text('Back', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: colors.muted.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: CardHtmlView(html: card.back),
            ),
            const SizedBox(height: 16),
            const Text('Fields', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 8),
            _buildFieldsTable(card.fields, colors),
            const SizedBox(height: 16),
            const Text('Card Info', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 8),
            OutlinedContainer(
              child: Column(
                children: [
                  _infoRow('Deck', card.deckTitle, colors),
                  _infoRow('Note Type', card.noteTypeName, colors),
                  _infoRow('State', card.state ?? 'new', colors),
                  _infoRow('Reps', card.reps.toString(), colors),
                  _infoRow('Lapses', card.lapses.toString(), colors),
                  _infoRow(
                      'Stability', card.stability.toStringAsFixed(2), colors),
                  _infoRow(
                      'Difficulty', card.difficulty.toStringAsFixed(2), colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteDetail(CardRecord card) {
    final colors = Theme.of(context).colorScheme;
    final noteStore = context.read<NoteStore>();
    final note = noteStore.note(card.noteId);
    final noteCards = _selectedNoteCards;
    final fields = note?.fields ?? card.fields;
    final noteTypeName = note?.noteTypeName ?? card.noteTypeName;
    final cardCount = note?.cardIds.length ?? noteCards.length;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Note Details'),
          trailing: [
            IconButton.outline(
              icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
              onPressed: () =>
                  _showCardActionsMenu(context, card, includeNote: false),
            ),
            IconButton.outline(
              icon: const Icon(LucideIcons.pencil, size: 20),
              onPressed: () => _showEditNoteDialog(card),
            ),
            IconButton.outline(
              icon: const Icon(LucideIcons.x, size: 20),
              onPressed: () => setState(() => _selectedCardIndex = null),
            ),
          ],
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fields', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 8),
            _buildFieldsTable(fields, colors),
            const SizedBox(height: 16),
            const Text('Note Info', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 8),
            OutlinedContainer(
              child: Column(
                children: [
                  _infoRow('Deck', card.deckTitle, colors),
                  _infoRow('Note Type', noteTypeName, colors),
                  _infoRow('Cards', cardCount.toString(), colors),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Cards', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 8),
            OutlinedContainer(
              child: Column(
                children: noteCards.asMap().entries.map((e) {
                  final c = e.value;
                  final displayState = c.state ?? 'new';
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colors.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Card ${e.key + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.front
                                    .replaceAll(RegExp(r'<[^>]*>'), ' ')
                                    .trim(),
                                style: TextStyle(
                                    color: colors.mutedForeground,
                                    fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlineBadge(
                          child: Text(displayState),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsTable(Map<String, dynamic> fields, ColorScheme colors) {
    return OutlinedContainer(
      child: Column(
        children: fields.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.border, width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    e.key,
                    style: TextStyle(
                      color: colors.mutedForeground,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value.toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: colors.mutedForeground,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  TableCell _buildStateCell(CardRecord card, {VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;

    final TableCellTheme cellTheme = TableCellTheme(
      border: WidgetStatePropertyAll(
        Border.all(
          color: colors.border,
          strokeAlign: BorderSide.strokeAlignCenter,
        ),
      ),
    );

    return TableCell(
      theme: cellTheme,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Consumer<CardStore>(
          builder: (context, store, _) {
            final record = store.card(card.cardId);
            final state = record?.state ?? card.state;
            final reps = record?.reps ?? card.reps;
            final displayState = state ?? (reps == 0 ? 'new' : null);
            if (displayState == null) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                alignment: Alignment.centerLeft,
                child:
                    Text('—', style: TextStyle(color: colors.mutedForeground)),
              );
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.centerLeft,
              child: OutlineBadge(
                child: Text(displayState),
              ),
            );
          },
        ),
      ),
    );
  }

  TableCell _buildDueCell(CardRecord card, {VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;

    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: colors.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Consumer<CardStore>(
          builder: (context, store, _) {
            // Read live due_at/newCardPosition from the store so a reschedule
            // anywhere reflects here without re-fetching the browse page.
            final record = store.card(card.cardId);
            final dueAt = record?.dueAt ?? card.dueAt;
            final newPos = record?.newCardPosition ?? card.newCardPosition;
            final state = record?.state ?? card.state;
            final isNewLive =
                state == 'new' || (state == null && card.reps == 0);
            final text = isNewLive && newPos != null
                ? 'New #$newPos'
                : dueAt != null
                    ? _formatDate(dueAt)
                    : '—';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(
                    color: isNewLive && newPos != null
                        ? const Color(0xFF3B82F6)
                        : colors.mutedForeground),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final due = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
  }

  String _stateLabel(String state) {
    return switch (state) {
      'root' => 'Card State',
      'new' => 'New',
      'learning' => 'Learning',
      'review' => 'Review',
      'relearning' => 'Relearning',
      'due' => 'Due',
      _ => state,
    };
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final void Function(String) onSearch;

  const _FilterBar({
    required this.searchController,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: ComponentTheme(
        data: const FocusOutlineTheme(align: 0),
        child: TextField(
          controller: searchController,
          placeholder: const Text('Search cards...'),
          borderRadius: BorderRadius.zero,
          features: [
            const InputFeature.leading(
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(LucideIcons.search, size: 18),
              ),
            ),
          ],
          onChanged: onSearch,
        ),
      ),
    );
  }
}

enum _CompactView { table, detail }
