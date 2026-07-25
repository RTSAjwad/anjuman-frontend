import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final _sortField = ValueNotifier<String>('created_at');
  final _sortAsc = ValueNotifier<bool>(false);
  final _scrollController = ScrollController();
  bool _fetchingMore = false;

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
  void dispose() {
    _searchController.dispose();
    _sortField.dispose();
    _sortAsc.dispose();
    _scrollController.dispose();
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

  void _onSort(String field) {
    if (_sortField.value == field) {
      _sortAsc.value = !_sortAsc.value;
    } else {
      _sortField.value = field;
      _sortAsc.value = true;
    }
    final order = _sortAsc.value ? '' : '-';
    context.read<BrowserProvider>().setSort('$order$field');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browser'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<BrowserProvider>().loadCards(),
          ),
        ],
      ),
      body: Column(
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
                        Text('Failed to load cards',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
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

                final theme = Theme.of(context);
                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Table(
                        columnWidths: const {
                          0: IntrinsicColumnWidth(),
                          1: IntrinsicColumnWidth(),
                          2: IntrinsicColumnWidth(),
                          3: IntrinsicColumnWidth(),
                        },
                        children: [
                          // Header
                          TableRow(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            children: [
                              _SortCell(
                                label: 'Sort Field',
                                field: 'question',
                                sortField: _sortField,
                                sortAsc: _sortAsc,
                                onTap: () => _onSort('question'),
                              ),
                              _SortCell(
                                label: 'Deck',
                                field: 'deck',
                                sortField: _sortField,
                                sortAsc: _sortAsc,
                                onTap: () => _onSort('deck'),
                              ),
                              _SortCell(
                                label: 'State',
                                field: '',
                                sortField: _sortField,
                                sortAsc: _sortAsc,
                                onTap: null,
                              ),
                              _SortCell(
                                label: 'Due',
                                field: 'due_at',
                                sortField: _sortField,
                                sortAsc: _sortAsc,
                                onTap: () => _onSort('due_at'),
                              ),
                            ],
                          ),
                          // Rows
                          for (final card in provider.cards)
                            TableRow(
                              children: [
                                _CardCell(card: card),
                                _DeckCell(card: card),
                                _StateCell(card: card),
                                _DueCell(card: card),
                              ],
                            ),
                        ],
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
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
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
              decoration: const InputDecoration(
                hintText: 'Search cards...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int?>(
              initialValue: provider.deckId,
              decoration: const InputDecoration(
                labelText: 'Deck',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All decks')),
                ...decks.map(
                  (d) => DropdownMenuItem(value: d.id, child: Text(d.title)),
                ),
              ],
              onChanged: (v) => context.read<BrowserProvider>().setDeckId(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortCell extends StatelessWidget {
  final String label;
  final String field;
  final ValueNotifier<String> sortField;
  final ValueNotifier<bool> sortAsc;
  final VoidCallback? onTap;

  const _SortCell({
    required this.label,
    required this.field,
    required this.sortField,
    required this.sortAsc,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = field.isNotEmpty
        ? ValueListenableBuilder(
            valueListenable: sortField,
            builder: (context, activeField, _) {
              final active = activeField == field;
              return ValueListenableBuilder(
                valueListenable: sortAsc,
                builder: (context, ascending, _) {
                  return InkWell(
                    onTap: () => onTap?.call(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w600,
                                fontSize: 12,
                                color: active
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (active)
                            Icon(
                              ascending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          );
    return child;
  }
}

class _CardCell extends StatelessWidget {
  final BrowserCard card;

  const _CardCell({required this.card});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        _stripTags(card.front),
        style: Theme.of(context).textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _DeckCell extends StatelessWidget {
  final BrowserCard card;

  const _DeckCell({required this.card});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        card.deckTitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StateCell extends StatelessWidget {
  final BrowserCard card;

  const _StateCell({required this.card});

  @override
  Widget build(BuildContext context) {
    final displayState = card.state ?? (card.reps == 0 ? 'new' : null);
    if (displayState == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text('—', style: TextStyle(fontSize: 13)),
      );
    }
    final theme = Theme.of(context);
    final (label, color) = switch (displayState) {
      'new' => ('new', Colors.blue),
      'learning' => ('learning', Colors.orange),
      'review' => ('review', Colors.green),
      'relearning' => ('relearn', Colors.purple),
      _ => (displayState, theme.colorScheme.onSurfaceVariant),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _DueCell extends StatelessWidget {
  final BrowserCard card;

  const _DueCell({required this.card});

  @override
  Widget build(BuildContext context) {
    final displayState = card.state ?? (card.reps == 0 ? 'new' : null);
    final isNew = displayState == 'new';

    final text = isNew && card.newCardPosition != null
        ? 'New #${card.newCardPosition}'
        : card.dueAt != null
            ? _formatDate(card.dueAt!)
            : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isNew && card.newCardPosition != null
                ? Colors.blue
                : Theme.of(context).colorScheme.onSurfaceVariant),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatDate(int timestamp) {
    final due = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
  }
}
