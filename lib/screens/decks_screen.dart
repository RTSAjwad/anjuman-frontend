import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Decks'),
          trailing: [
            IconButton.ghost(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => context.read<DeckProvider>().loadDecks(),
            ),
          ],
        ),
      ],
      child: Consumer<DeckProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.decks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.decks.isEmpty) {
            return _errorView(context, provider, colors);
          }

          if (provider.decks.isEmpty) {
            return _emptyView(context, isTeacher, colors);
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

          return ListView(
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
                onDelete:
                    isTeacher ? (deck) => _confirmDelete(context, deck) : null,
                colors: colors,
              ),
            ],
          );
        },
      ),
      footers: isTeacher
          ? [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Button.primary(
                    onPressed: () => _showCreateDialog(context),
                    leading: const Icon(Icons.add, size: 18),
                    child: const Text('Create Deck'),
                  ),
                ),
              ),
            ]
          : [],
    );
  }

  Widget _errorView(
      BuildContext context, DeckProvider provider, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: colors.destructive),
          const SizedBox(height: 16),
          const Text('Failed to load decks'),
          const SizedBox(height: 8),
          Button.secondary(
            onPressed: () => provider.loadDecks(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyView(BuildContext context, bool isTeacher, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined, size: 64, color: colors.mutedForeground),
          const SizedBox(height: 16),
          Text(isTeacher ? 'No decks yet' : 'No decks available'),
          const SizedBox(height: 8),
          Text(
            isTeacher
                ? 'Create your first deck to get started'
                : 'No decks are available yet',
            style: TextStyle(color: colors.mutedForeground, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) {
          final provider = context.read<DeckProvider>();
          return _DeckFormDialog(
            title: 'Create Deck',
            provider: provider,
            onSuccess: () => Navigator.of(ctx).pop(),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, DeckResponse deck) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Deck'),
          content: Text('Delete "${deck.title}"? This cannot be undone.'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
              onPressed: () async {
                final ok =
                    await context.read<DeckProvider>().deleteDeck(deck.id);
                if (ok && ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        ),
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
  final ColorScheme colors;

  const _DeckTable({
    required this.decks,
    required this.sort,
    required this.isTeacher,
    required this.onSortChanged,
    required this.onStudy,
    required this.onTapDetail,
    this.onDelete,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final countWidth = _maxCountWidth(decks);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: colors.muted,
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
              for (final deck in decks)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => isTeacher ? onTapDetail(deck) : onStudy(deck),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            deck.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isTeacher)
                          SizedBox(
                            width: countWidth,
                            child: _CountText(
                              value: deck.totalCount ?? 0,
                              color: colors.foreground,
                            ),
                          )
                        else ...[
                          SizedBox(
                            width: countWidth,
                            child: _CountText(
                              value: deck.newCount ?? 0,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          SizedBox(
                            width: countWidth,
                            child: _CountText(
                              value: (deck.learningCount ?? 0) +
                                  (deck.relearningCount ?? 0),
                              color: const Color(0xFFF97316),
                            ),
                          ),
                          SizedBox(
                            width: countWidth,
                            child: _CountText(
                              value: deck.dueCount ?? 0,
                              color: const Color(0xFF22C55E),
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
    return maxWidth + 16;
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
    final colors = Theme.of(context).colorScheme;

    final cell = GestureDetector(
      behavior: HitTestBehavior.opaque,
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
                  color: active ? colors.primary : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active)
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: colors.primary,
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
    final colors = Theme.of(context).colorScheme;
    return Text(
      value > 0 ? '$value' : '—',
      style: TextStyle(
        color: value > 0 ? color : colors.mutedForeground,
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final description = _descriptionController.text.trim();
    final ok = await widget.provider.createDeck(
      title,
      description.isEmpty ? null : description,
    );

    if (mounted) {
      if (ok) {
        widget.onSuccess();
      } else {
        setState(() {
          _isSubmitting = false;
          _error = widget.provider.error ?? 'Failed to create deck';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              placeholder: const Text('Title'),
              initialValue: '',
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              placeholder: const Text('Description (optional)'),
              initialValue: '',
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: colors.destructive,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button.ghost(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Button.primary(
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
