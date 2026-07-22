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

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                // Header
                                Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      _SortHeader(
                                        flex: 4,
                                        label: 'Front',
                                        field: 'question',
                                        sortField: _sortField,
                                        sortAsc: _sortAsc,
                                        onTap: _onSort,
                                      ),
                                      _SortHeader(
                                        flex: 4,
                                        label: 'Back',
                                        field: 'question',
                                        sortField: _sortField,
                                        sortAsc: _sortAsc,
                                        onTap: _onSort,
                                      ),
                                      _SortHeader(
                                        flex: 2,
                                        label: 'Deck',
                                        field: 'deck',
                                        sortField: _sortField,
                                        sortAsc: _sortAsc,
                                        onTap: _onSort,
                                      ),
                                      _SortHeader(
                                        flex: 2,
                                        label: 'State',
                                        field: '',
                                        sortField: _sortField,
                                        sortAsc: _sortAsc,
                                        onTap: _onSort,
                                      ),
                                      _SortHeader(
                                        flex: 1,
                                        label: 'Due',
                                        field: 'due_at',
                                        sortField: _sortField,
                                        sortAsc: _sortAsc,
                                        onTap: _onSort,
                                      ),
                                    ],
                                  ),
                                ),
                                // Rows
                                for (final card in provider.cards)
                                  _CardRow(card: card),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PaginationBar(
                      page: provider.page,
                      total: provider.total,
                      perPage: provider.perPage,
                      hasPrev: provider.hasPrevPage,
                      hasNext: provider.hasNextPage,
                      onPrev: () => provider.prevPage(),
                      onNext: () => provider.nextPage(),
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

class _SortHeader extends StatelessWidget {
  final int flex;
  final String label;
  final String field;
  final ValueNotifier<String> sortField;
  final ValueNotifier<bool> sortAsc;
  final void Function(String) onTap;

  const _SortHeader({
    required this.flex,
    required this.label,
    required this.field,
    required this.sortField,
    required this.sortAsc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (field.isEmpty) {
      return Expanded(
        flex: flex,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      );
    }

    return Expanded(
      flex: flex,
      child: ValueListenableBuilder(
        valueListenable: sortField,
        builder: (context, activeField, _) {
          final active = activeField == field;
          return ValueListenableBuilder(
            valueListenable: sortAsc,
            builder: (context, ascending, _) {
              return InkWell(
                onTap: () => onTap(field),
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
                        ascending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final BrowserCard card;

  const _CardRow({required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              _stripTags(card.front),
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _stripTags(card.back),
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              card.deckTitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: _StateBadge(state: card.state),
          ),
          Expanded(
            flex: 1,
            child: Text(
              card.state != null && card.dueAt != null
                  ? _formatDue(card.dueAt!)
                  : '—',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatDue(int timestamp) {
    final due = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.inDays > 1) return '${diff.inDays}d';
    if (diff.inHours > 1) return '${diff.inHours}h';
    if (diff.inMinutes > 1) return '${diff.inMinutes}m';
    return 'now';
  }
}

class _StateBadge extends StatelessWidget {
  final String? state;

  const _StateBadge({this.state});

  @override
  Widget build(BuildContext context) {
    if (state == null) return const Text('—', style: TextStyle(fontSize: 13));
    final theme = Theme.of(context);
    final (label, color) = switch (state) {
      'new' => ('new', Colors.blue),
      'learning' => ('learning', Colors.orange),
      'review' => ('review', Colors.green),
      'relearning' => ('relearn', Colors.purple),
      _ => (state!, theme.colorScheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int total;
  final int perPage;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PaginationBar({
    required this.page,
    required this.total,
    required this.perPage,
    required this.hasPrev,
    required this.hasNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final first = (page - 1) * perPage + 1;
    final last = (page * perPage).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: hasPrev ? onPrev : null,
          ),
          Text('$first–$last of $total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: hasNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}
