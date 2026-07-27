import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/auth_provider.dart';
import '../providers/browser_provider.dart';
import '../providers/deck_provider.dart';
import '../models/browser_card.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeckProvider>().loadDecks();
      context.read<BrowserProvider>().loadCards();
    });
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
      _columns = ['Sort Field', 'Deck', 'State', 'Due'];
      _sortFields = ['question', 'deck', '', 'due_at'];
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
          title: const Text('Browser'),
          trailing: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: () => context.read<BrowserProvider>().loadCards(),
            ),
          ],
        ),
      ],
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
                                color: colors.mutedForeground, fontSize: 13)),
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
                      _buildCell(card.deckTitle),
                      _buildStateCell(card),
                      _buildDueCell(card),
                    ]));
                  }
                }

                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  children: [
                    OutlinedContainer(
                      child: ResizableTable(
                        controller: _tableController,
                        rows: rows,
                      ),
                    ),
                    if (provider.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!provider.hasNextPage && provider.cards.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${provider.total} cards total',
                          style: TextStyle(
                              color: colors.mutedForeground, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
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

    final (label, bgColor, textColor) = switch (displayState) {
      'new' => (
          'new',
          const Color(0xFF3B82F6).withValues(alpha: 0.15),
          const Color(0xFF3B82F6)
        ),
      'learning' => (
          'learning',
          const Color(0xFFF97316).withValues(alpha: 0.15),
          const Color(0xFFF97316)
        ),
      'review' => (
          'review',
          const Color(0xFF22C55E).withValues(alpha: 0.15),
          const Color(0xFF22C55E)
        ),
      'relearning' => (
          'relearn',
          const Color(0xFFA855F7).withValues(alpha: 0.15),
          const Color(0xFFA855F7)
        ),
      _ => (displayState, colors.muted, colors.foreground),
    };

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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 11, color: textColor, fontWeight: FontWeight.w600),
          ),
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
    final decks = context.watch<DeckProvider>().decks;
    final provider = context.read<BrowserProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
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
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: Select<int?>(
              value: provider.deckId,
              placeholder: const Text('All decks'),
              onChanged: (v) => context.read<BrowserProvider>().setDeckId(v),
              popup: SelectPopup(
                items: SelectItemList(children: [
                  const SelectItemButton(value: null, child: Text('All decks')),
                  for (final d in decks)
                    SelectItemButton(
                      value: d.id,
                      child: Text(d.title),
                    ),
                ]),
              ),
              itemBuilder: (context, value) {
                if (value == null) return const Text('All decks');
                final d = decks.where((d) => d.id == value).firstOrNull;
                return Text(d?.title ?? '');
              },
            ),
          ),
        ],
      ),
    );
  }
}
