import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/auth_provider.dart';
import '../providers/browser_provider.dart';
import '../providers/deck_provider.dart';
import '../models/browser_card.dart';
import '../models/deck.dart';
import '../widgets/deck_tree.dart';
import '../widgets/responsive_dialog.dart';
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

  List<TreeNode<FilterNode>> _filterNodes = [];

  int? _selectedCardIndex;
  int _activeTab = 0; // 0 = Cards, 1 = Notes
  BrowserCard? get _selectedCard {
    if (_selectedCardIndex == null) return null;
    final cards = context.read<BrowserProvider>().cards;
    if (_selectedCardIndex! >= cards.length) return null;
    return cards[_selectedCardIndex!];
  }

  List<BrowserCard> get _selectedNoteCards {
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
      final root = _buildDeckTree(decks);
      _replaceOrAddSection('decks', root);
    });
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
    return null;
  }

  bool _isSectionRoot(FilterNode data) => _sectionKey(data) != null;

  String _sectionLabel(FilterNode data) {
    if (data is DeckFilterNode) return data.deck.title;
    if (data is StateFilterNode) return _stateLabel(data.state);
    if (data is NoteTypeFilterNode) return data.noteType.name;
    return '';
  }

  void _syncAllFilters(List<TreeNode<FilterNode>> nodes) {
    final deckIds = <int>[];
    final states = <String>[];
    final noteTypeIds = <int>[];
    _walkSelected(nodes, deckIds, states, noteTypeIds);
    context.read<BrowserProvider>().setFilters(
          deckIds: deckIds,
          states: states,
          noteTypeIds: noteTypeIds,
        );
  }

  void _walkSelected(
    List<TreeNode<FilterNode>> nodes,
    List<int> deckIds,
    List<String> states,
    List<int> noteTypeIds,
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
        }
      }
      _walkSelected(node.children, deckIds, states, noteTypeIds);
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
          _buildCell(card.deckTitle, onTap: onTap),
        ]));
      }
    }
  }

  void _buildNoteRows(BrowserProvider provider, ColorScheme colors,
      bool isTeacher, List<TableRow> rows) {
    final grouped = <int, List<BrowserCard>>{};
    for (final card in provider.cards) {
      grouped.putIfAbsent(card.noteId, () => []).add(card);
    }

    final entries = grouped.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final cards = entries[i].value;
      final firstCard = cards.first;
      final sortField =
          firstCard.front.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();

      final onTap = () {
        final cardIndex =
            provider.cards.indexWhere((c) => c.noteId == firstCard.noteId);
        setState(() {
          if (_selectedCardIndex == cardIndex) {
            _selectedCardIndex = null;
          } else {
            _selectedCardIndex = cardIndex;
          }
        });
      };

      final cardsLabel = '${cards.length} card${cards.length == 1 ? '' : 's'}';

      if (isTeacher) {
        rows.add(TableRow(cells: [
          _buildCell(sortField, onTap: onTap),
          _buildCell(cardsLabel, onTap: onTap),
          _buildCell(firstCard.noteTypeName, onTap: onTap),
        ]));
      } else {
        rows.add(TableRow(cells: [
          _buildCell(sortField, onTap: onTap),
          _buildCell(cardsLabel, onTap: onTap),
          _buildCell(firstCard.noteTypeName, onTap: onTap),
          _buildCell(firstCard.deckTitle, onTap: onTap),
        ]));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      child: Column(
        children: [
          AppBar(
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
            trailing: [
              Button.ghost(
                onPressed: () => setState(() => _activeTab = 0),
                child: Text(
                  'Cards',
                  style: TextStyle(
                    fontWeight:
                        _activeTab == 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              Button.ghost(
                onPressed: () => setState(() => _activeTab = 1),
                child: Text(
                  'Notes',
                  style: TextStyle(
                    fontWeight:
                        _activeTab == 1 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              IconButton.outline(
                icon: const Icon(LucideIcons.refreshCw, size: 20),
                onPressed: () => context.read<BrowserProvider>().loadCards(),
              ),
            ],
          ),
          Expanded(
            child: ResizablePanel.horizontal(
              draggerBuilder: (context) {
                return const HorizontalResizableDragger();
              },
              children: [
                ResizablePane(
                  initialSize: 220,
                  minSize: 160,
                  child: _filterNodes.length <= 1
                      ? const Center(child: CircularProgressIndicator())
                      : Theme(
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
                                onPressed:
                                    (isSection || hasChildren) ? null : () {},
                                onExpand: (isSection || hasChildren)
                                    ? Tree.defaultItemExpandHandler(
                                        _filterNodes,
                                        node,
                                        (value) {
                                          setState(() => _filterNodes = value);
                                        },
                                      )
                                    : null,
                                child: Text(
                                  _sectionLabel(data),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                ),
                ResizablePane.flex(
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
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (provider.error != null &&
                                provider.cards.isEmpty) {
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
                              return const Center(child: Text('Nothing found'));
                            }

                            final headerCells = <TableCell>[];
                            if (_activeTab == 0) {
                              for (var i = 0; i < _columns.length; i++) {
                                final active = _activeSort == _sortFields[i];
                                headerCells.add(_buildHeader(
                                    colors, i, active, _columns[i]));
                              }
                            } else {
                              headerCells.add(
                                  _buildHeader(colors, 0, false, 'Sort Field'));
                              headerCells
                                  .add(_buildHeader(colors, 1, false, 'Cards'));
                              headerCells.add(
                                  _buildHeader(colors, 2, false, 'Note Type'));
                            }

                            final rows = <TableRow>[
                              TableHeader(cells: headerCells),
                            ];

                            final role = context.read<AuthProvider>().role;
                            final isTeacher =
                                role == 'teacher' || role == 'admin';

                            if (_activeTab == 0) {
                              _buildCardRows(provider, colors, isTeacher, rows);
                            } else {
                              _buildNoteRows(provider, colors, isTeacher, rows);
                            }

                            return ListView(
                              controller: _scrollController,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: constraints.maxWidth,
                                        ),
                                        child: ResizableTable(
                                          controller: _tableController,
                                          rows: rows,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (provider.isLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedCard != null &&
                    !context.watch<BrowserProvider>().isLoading)
                  ResizablePane.flex(
                    child: _buildCardDetailPane(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNoteDialog(BrowserCard card) {
    final provider = context.read<DeckProvider>();
    final noteCards = _selectedNoteCards;
    final note = NoteResponse(
      id: card.noteId,
      deckIds: [card.deckId],
      noteTypeId: 0,
      noteTypeName: card.noteTypeName,
      fields: card.fields,
      cards: noteCards
          .map((c) => CardSummary(
                id: c.cardId,
                templateIndex: c.templateIndex,
                front: c.front,
                back: c.back,
              ))
          .toList(),
      createdAt: card.createdAt,
    );
    showResponsiveDialog(
      context,
      builder: (ctx, _) => NoteFormDialog(
        deckId: card.deckId,
        provider: provider,
        existingNote: note,
        onSuccess: () {
          safeCloseOverlay(ctx);
          context.read<BrowserProvider>().loadCards();
        },
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

  Widget _buildCardDetail(BrowserCard card) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Card Details'),
          trailing: [
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.muted.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(card.front),
            ),
            const SizedBox(height: 16),
            const Text('Back', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.muted.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(card.back),
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

  Widget _buildNoteDetail(BrowserCard card) {
    final colors = Theme.of(context).colorScheme;
    final noteCards = _selectedNoteCards;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Note Details'),
          trailing: [
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
            _buildFieldsTable(card.fields, colors),
            const SizedBox(height: 16),
            const Text('Note Info', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 8),
            OutlinedContainer(
              child: Column(
                children: [
                  _infoRow('Deck', card.deckTitle, colors),
                  _infoRow('Note Type', card.noteTypeName, colors),
                  _infoRow('Cards', noteCards.length.toString(), colors),
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

  TableCell _buildStateCell(BrowserCard card, {VoidCallback? onTap}) {
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Text('—', style: TextStyle(color: colors.mutedForeground)),
          ),
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.centerLeft,
          child: OutlineBadge(
            child: Text(displayState),
          ),
        ),
      ),
    );
  }

  TableCell _buildDueCell(BrowserCard card, {VoidCallback? onTap}) {
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
