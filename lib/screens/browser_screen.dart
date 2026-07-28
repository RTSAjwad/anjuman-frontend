import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/auth_provider.dart';
import '../providers/browser_provider.dart';
import '../providers/deck_provider.dart';
import '../models/browser_card.dart';
import '../models/deck.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _fetchingMore = false;

  final ResizableTableController _tableController = ResizableTableController(
    defaultColumnWidth: 150,
    defaultRowHeight: 40,
    defaultHeightConstraint: const ConstrainedTableSize(min: 40),
    defaultWidthConstraint: const ConstrainedTableSize(min: 80),
  );

  List<String> _columns = ['Sort Field', 'Deck'];
  List<String> _sortFields = ['question', 'deck'];
  String _activeSort = 'created_at';
  bool _sortAsc = false;

  List<TreeNode<DeckResponse>> _treeNodes = [];
  List<TreeNode<String>> _stateNodes = [];
  List<TreeNode<NoteType>> _noteTypeNodes = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _stateNodes = [
      TreeItemNode<String>(
        data: 'root',
        expanded: true,
        children: [
          TreeItemNode(data: 'new', children: []),
          TreeItemNode(data: 'learning', children: []),
          TreeItemNode(data: 'review', children: []),
          TreeItemNode(data: 'relearning', children: []),
          TreeItemNode(data: 'due', children: []),
        ],
      ),
    ];
    final deckProvider = context.read<DeckProvider>();
    deckProvider.addListener(_onDecksChanged);
    deckProvider.addListener(_onNoteTypesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      deckProvider.loadDecks();
      deckProvider.loadNoteTypes();
      context.read<BrowserProvider>().loadCards();
    });
  }

  void _onDecksChanged() {
    final decks = context.read<DeckProvider>().decks;
    if (decks.isEmpty) return;
    setState(() {
      _treeNodes = [
        TreeItemNode<DeckResponse>(
          data: DeckResponse(
            id: -1,
            schoolId: 0,
            title: 'Decks',
            createdBy: 0,
            createdAt: DateTime.now(),
          ),
          expanded: true,
          children: decks
              .map((d) => TreeItemNode<DeckResponse>(
                    data: d,
                    children: [],
                  ))
              .toList(),
        ),
      ];
    });
  }

  void _onNoteTypesChanged() {
    final noteTypes = context.read<DeckProvider>().noteTypes;
    if (noteTypes.isEmpty) return;
    setState(() {
      _noteTypeNodes = [
        TreeItemNode<NoteType>(
          data: NoteType(
            id: -1,
            name: 'Note Type',
            fieldNames: [],
            sortField: '',
            templates: [],
            noteCount: 0,
          ),
          expanded: true,
          children: noteTypes
              .map((nt) => TreeItemNode<NoteType>(
                    data: nt,
                    children: [],
                  ))
              .toList(),
        ),
      ];
    });
  }

  void _syncDeckSelection(List<TreeNode<DeckResponse>> nodes) {
    final ids = _collectSelected<DeckResponse, int>(
        nodes, (d) => d.id != -1, (d) => d.id);
    context.read<BrowserProvider>().setDeckIds(ids);
  }

  void _syncStateSelection(List<TreeNode<String>> nodes) {
    final states =
        _collectSelected<String, String>(nodes, (s) => s != 'root', (s) => s);
    context.read<BrowserProvider>().setStates(states);
  }

  void _syncNoteTypeSelection(List<TreeNode<NoteType>> nodes) {
    final ids = _collectSelected<NoteType, int>(
        nodes, (nt) => nt.id != -1, (nt) => nt.id);
    context.read<BrowserProvider>().setNoteTypeIds(ids);
  }

  List<R> _collectSelected<T, R>(
    List<TreeNode<T>> nodes,
    bool Function(T) filter,
    R Function(T) map,
  ) {
    final result = <R>[];
    for (final node in nodes) {
      if (node is TreeItemNode<T> && node.selected && filter(node.data)) {
        result.add(map(node.data));
      }
      result.addAll(_collectSelected(node.children, filter, map));
    }
    return result;
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
      _columns = ['Sort Field', 'State', 'Due', 'Deck'];
      _sortFields = ['question', '', 'due_at', 'deck'];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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

  TableCell _buildCell(String text, [bool alignRight = false]) {
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Browser'),
              const SizedBox(width: 12),
              Consumer<BrowserProvider>(
                builder: (context, provider, _) {
                  if (provider.total == 0) {
                    return const SizedBox.shrink();
                  }
                  return OutlineBadge(
                    child: Text(
                        '${provider.total} card${provider.total == 1 ? '' : 's'} selected'),
                  );
                },
              ),
            ],
          ),
          trailing: [
            IconButton.outline(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: () => context.read<BrowserProvider>().loadCards(),
            ),
          ],
        ),
      ],
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Column(
              children: [
                Expanded(
                  child: _treeNodes.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          children: [
                            OutlinedContainer(
                              child: Tree<DeckResponse>(
                                shrinkWrap: true,
                                allowMultiSelect: true,
                                nodes: _treeNodes,
                                branchLine: BranchLine.line,
                                onSelectionChanged:
                                    Tree.defaultSelectionHandler(
                                  _treeNodes,
                                  (value) {
                                    setState(() {
                                      _treeNodes = value;
                                      _syncDeckSelection(value);
                                    });
                                  },
                                ),
                                builder: (context, node) {
                                  final deck = node.data;
                                  final isRoot = deck.id == -1;
                                  return TreeItem(
                                    onPressed: isRoot ? null : () {},
                                    onExpand: isRoot
                                        ? Tree.defaultItemExpandHandler(
                                            _treeNodes,
                                            node,
                                            (value) {
                                              setState(
                                                  () => _treeNodes = value);
                                            },
                                          )
                                        : null,
                                    child: Text(
                                      deck.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedContainer(
                              child: Tree<String>(
                                shrinkWrap: true,
                                allowMultiSelect: true,
                                nodes: _stateNodes,
                                branchLine: BranchLine.line,
                                onSelectionChanged:
                                    Tree.defaultSelectionHandler(
                                  _stateNodes,
                                  (value) {
                                    setState(() {
                                      _stateNodes = value;
                                      _syncStateSelection(value);
                                    });
                                  },
                                ),
                                builder: (context, node) {
                                  final state = node.data;
                                  final isRoot = state == 'root';
                                  return TreeItem(
                                    onPressed: isRoot ? null : () {},
                                    onExpand: isRoot
                                        ? Tree.defaultItemExpandHandler(
                                            _stateNodes,
                                            node,
                                            (value) {
                                              setState(
                                                  () => _stateNodes = value);
                                            },
                                          )
                                        : null,
                                    child: Text(
                                      _stateLabel(state),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_noteTypeNodes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedContainer(
                                child: Tree<NoteType>(
                                  shrinkWrap: true,
                                  allowMultiSelect: true,
                                  nodes: _noteTypeNodes,
                                  branchLine: BranchLine.line,
                                  onSelectionChanged:
                                      Tree.defaultSelectionHandler(
                                    _noteTypeNodes,
                                    (value) {
                                      setState(() {
                                        _noteTypeNodes = value;
                                        _syncNoteTypeSelection(value);
                                      });
                                    },
                                  ),
                                  builder: (context, node) {
                                    final noteType = node.data;
                                    final isRoot = noteType.id == -1;
                                    return TreeItem(
                                      onPressed: isRoot ? null : () {},
                                      onExpand: isRoot
                                          ? Tree.defaultItemExpandHandler(
                                              _noteTypeNodes,
                                              node,
                                              (value) {
                                                setState(() =>
                                                    _noteTypeNodes = value);
                                              },
                                            )
                                          : null,
                                      child: Text(
                                        noteType.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _FilterBar(
                  searchController: _searchController,
                  onSearch: _onSearch,
                ),
                Expanded(
                  child: Consumer<BrowserProvider>(
                    builder: (context, provider, _) {
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
                                  style: TextStyle(
                                      color: colors.mutedForeground,
                                      fontSize: 13)),
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
                        return const Center(child: Text('No cards found'));
                      }

                      final headerCells = <TableCell>[];
                      for (var i = 0; i < _columns.length; i++) {
                        final active = _activeSort == _sortFields[i];
                        headerCells.add(TableCell(
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
                            onTap: () => _onSort(i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _columns[i],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: active
                                            ? colors.primary
                                            : colors.mutedForeground,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (active)
                                    Icon(
                                      _sortAsc
                                          ? LucideIcons.arrowUp
                                          : LucideIcons.arrowDown,
                                      size: 14,
                                      color: colors.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ));
                      }

                      final rows = <TableRow>[
                        TableHeader(cells: headerCells),
                      ];

                      for (final card in provider.cards) {
                        final frontText = card.front
                            .replaceAll(RegExp(r'<[^>]*>'), ' ')
                            .replaceAll(RegExp(r'\s+'), ' ')
                            .trim();

                        final role = context.read<AuthProvider>().role;
                        final isTeacher = role == 'teacher' || role == 'admin';

                        if (isTeacher) {
                          rows.add(TableRow(cells: [
                            _buildCell(frontText),
                            _buildCell(card.deckTitle),
                          ]));
                        } else {
                          rows.add(TableRow(cells: [
                            _buildCell(frontText),
                            _buildStateCell(card),
                            _buildDueCell(card),
                            _buildCell(card.deckTitle),
                          ]));
                        }
                      }

                      return ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: OutlinedContainer(
                                    child: ResizableTable(
                                      controller: _tableController,
                                      rows: rows,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (provider.isLoading)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableCell _buildStateCell(BrowserCard card) {
    final colors = Theme.of(context).colorScheme;
    final displayState = card.state ?? (card.reps == 0 ? 'new' : null);
    if (displayState == null) {
      return TableCell(
        theme: TableCellTheme(
          border: WidgetStatePropertyAll(
            Border.all(
              color: colors.border,
              strokeAlign: BorderSide.strokeAlignCenter,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.centerLeft,
          child: Text('—', style: TextStyle(color: colors.mutedForeground)),
        ),
      );
    }

    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: colors.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.centerLeft,
        child: OutlineBadge(
          child: Text(displayState),
        ),
      ),
    );
  }

  TableCell _buildDueCell(BrowserCard card) {
    final colors = Theme.of(context).colorScheme;
    final displayState = card.state ?? (card.reps == 0 ? 'new' : null);
    final isNew = displayState == 'new';

    final text = isNew && card.newCardPosition != null
        ? 'New #${card.newCardPosition}'
        : card.dueAt != null
            ? _formatDate(card.dueAt!)
            : '—';

    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: colors.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
              color: isNew && card.newCardPosition != null
                  ? const Color(0xFF3B82F6)
                  : colors.mutedForeground),
          overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: searchController,
        placeholder: const Text('Search cards...'),
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
    );
  }
}
