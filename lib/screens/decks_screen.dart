import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/study_provider.dart';
import '../models/deck.dart';
import '../widgets/sortable_table.dart';
import 'deck_detail_screen.dart';
import 'study_screen.dart';

class DecksScreen extends StatefulWidget {
  const DecksScreen({super.key});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  final _sort =
      TableSort<DeckResponse, DeckSortField>(DeckSortField.title, true);
  bool _initialLoadDone = false;

  void _reloadDecks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DeckProvider>().loadDecks();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _reloadDecks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadDone) {
      _reloadDecks();
    }
    _initialLoadDone = true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTeacher = auth.role == 'teacher' || auth.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<DeckProvider>().loadDecks(),
          ),
        ],
      ),
      body: Consumer<DeckProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.decks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.decks.isEmpty) {
            return _errorView(context, provider);
          }

          if (provider.decks.isEmpty) {
            return _emptyView(context, isTeacher);
          }

          final sorted = _sort.sort(
              provider.decks,
              (d, f) => switch (f) {
                    DeckSortField.title => d.title,
                    DeckSortField.newCount => d.newCount ?? 0,
                    DeckSortField.learning =>
                      (d.learningCount ?? 0) + (d.relearningCount ?? 0),
                    DeckSortField.due => d.dueCount ?? 0,
                    DeckSortField.cards => d.totalCount ?? 0,
                  });

          return RefreshIndicator(
            onRefresh: () => provider.loadDecks(),
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _DeckTable(
                  decks: sorted,
                  sort: _sort,
                  isTeacher: isTeacher,
                  onSortChanged: () => setState(() {}),
                  onStudy: (deck) async {
                    final studyProvider = context.read<StudyProvider>();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudyScreen(
                          deckId: deck.id,
                          provider: studyProvider,
                        ),
                      ),
                    );
                    provider.loadDecks();
                  },
                  onTapDetail: (deck) {
                    final classProvider = context.read<ClassProvider>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeckDetailScreen(
                          deck: deck,
                          provider: provider,
                          classProvider: classProvider,
                        ),
                      ),
                    );
                  },
                  onDelete: isTeacher
                      ? (deck) => _confirmDelete(context, deck)
                      : null,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              heroTag: 'create_deck',
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Deck'),
            )
          : null,
    );
  }

  Widget _errorView(BuildContext context, DeckProvider provider) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('Failed to load decks', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => provider.loadDecks(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyView(BuildContext context, bool isTeacher) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            isTeacher ? 'No decks yet' : 'No decks available',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isTeacher
                ? 'Create your first deck to get started'
                : 'No decks are available yet',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _DeckFormDialog(
        title: 'Create Deck',
        provider: context.read<DeckProvider>(),
        onSuccess: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DeckResponse deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('Delete "${deck.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final ok = await context.read<DeckProvider>().deleteDeck(deck.id);
              if (ok && ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DeckTable extends StatelessWidget {
  final List<DeckResponse> decks;
  final TableSort<DeckResponse, DeckSortField> sort;
  final bool isTeacher;
  final VoidCallback onSortChanged;
  final void Function(DeckResponse) onStudy;
  final void Function(DeckResponse) onTapDetail;
  final void Function(DeckResponse)? onDelete;

  const _DeckTable({
    required this.decks,
    required this.sort,
    required this.isTeacher,
    required this.onSortChanged,
    required this.onStudy,
    required this.onTapDetail,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Pre-compute the maximum count value string width.
    // Used to align the count columns across header and rows.
    final countWidth = _maxCountWidth(decks);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _SortCell(
                        active: sort.field == DeckSortField.title,
                        ascending: sort.ascending,
                        label: 'Deck',
                        onTap: () {
                          sort.toggle(DeckSortField.title);
                          onSortChanged();
                        },
                      ),
                    ),
                    if (isTeacher)
                      _SortCell(
                        active: sort.field == DeckSortField.cards,
                        ascending: sort.ascending,
                        label: 'Cards',
                        width: countWidth,
                        onTap: () {
                          sort.toggle(DeckSortField.cards);
                          onSortChanged();
                        },
                      )
                    else ...[
                      _SortCell(
                        active: sort.field == DeckSortField.newCount,
                        ascending: sort.ascending,
                        label: 'New',
                        width: countWidth,
                        onTap: () {
                          sort.toggle(DeckSortField.newCount);
                          onSortChanged();
                        },
                      ),
                      _SortCell(
                        active: sort.field == DeckSortField.learning,
                        ascending: sort.ascending,
                        label: 'Learning',
                        width: countWidth,
                        onTap: () {
                          sort.toggle(DeckSortField.learning);
                          onSortChanged();
                        },
                      ),
                      _SortCell(
                        active: sort.field == DeckSortField.due,
                        ascending: sort.ascending,
                        label: 'Due',
                        width: countWidth,
                        onTap: () {
                          sort.toggle(DeckSortField.due);
                          onSortChanged();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              // Rows
              for (final deck in decks)
                InkWell(
                  onTap: () => isTeacher ? onTapDetail(deck) : onStudy(deck),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  deck.title,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isTeacher)
                          SizedBox(
                            width: countWidth,
                            child: _CountText(
                              value: deck.totalCount ?? 0,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else ...[
                          SizedBox(
                            width: countWidth,
                            child: _CountText(
                              value: deck.newCount ?? 0,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(
                            width: countWidth,
                            child: _CountText(
                              value: (deck.learningCount ?? 0) +
                                  (deck.relearningCount ?? 0),
                              color: Colors.orange,
                            ),
                          ),
                          SizedBox(
                            width: countWidth,
                            child: _CountText(
                              value: deck.dueCount ?? 0,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _maxCountWidth(List<DeckResponse> decks) {
    final labels =
        isTeacher ? <String>['Cards'] : <String>['New', 'Learning', 'Due'];
    final allValues = <String>[
      ...labels,
      for (final d in decks)
        if (isTeacher)
          '${d.totalCount ?? 0}'
        else ...[
          '${d.newCount ?? 0}',
          '${(d.learningCount ?? 0) + (d.relearningCount ?? 0)}',
          '${d.dueCount ?? 0}',
          '—',
        ],
    ];

    // Use a TextPainter to measure the widest string at fontSize 13 with weight 600.
    double maxWidth = 0;
    for (final text in allValues) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > maxWidth) maxWidth = tp.width;
    }
    return maxWidth + 16; // 8px padding on each side
  }
}

class _SortCell extends StatelessWidget {
  final bool active;
  final bool ascending;
  final String label;
  final double? width;
  final VoidCallback onTap;

  const _SortCell({
    required this.active,
    required this.ascending,
    required this.label,
    this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cell = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                  color: active ? Theme.of(context).colorScheme.primary : null,
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
      ),
    );
    if (width != null) {
      return SizedBox(width: width, child: cell);
    }
    return cell;
  }
}

class _CountText extends StatelessWidget {
  final int value;
  final Color color;

  const _CountText({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      value > 0 ? '$value' : '—',
      style: TextStyle(
        color: value > 0
            ? color
            : Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100),
        fontWeight: value > 0 ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13,
      ),
      textAlign: TextAlign.center,
    );
  }
}

enum DeckSortField { title, newCount, learning, due, cards }

class _DeckFormDialog extends StatefulWidget {
  final String title;
  final DeckProvider provider;
  final VoidCallback onSuccess;

  const _DeckFormDialog({
    required this.title,
    required this.provider,
    required this.onSuccess,
  });

  @override
  State<_DeckFormDialog> createState() => _DeckFormDialogState();
}

class _DeckFormDialogState extends State<_DeckFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final ok = await widget.provider.createDeck(
      _titleController.text.trim(),
      _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (mounted) {
      if (ok) {
        widget.onSuccess();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.provider.error ?? 'Failed to create deck'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Biology Chapter 5',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
