import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/study_provider.dart';
import '../models/deck.dart';
import '../widgets/sortable_table.dart';
import '../widgets/shadcn_page_route.dart';
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
            if (isTeacher)
              IconButton.ghost(
                icon: const Icon(LucideIcons.plus, size: 20),
                onPressed: () => _showCreateDialog(context),
              ),
            IconButton.ghost(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
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
                    ShadcnPageRoute(
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
                    ShadcnPageRoute(
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
    );
  }

  Widget _errorView(
      BuildContext context, DeckProvider provider, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circleAlert, size: 48, color: colors.destructive),
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
          Icon(LucideIcons.layers, size: 64, color: colors.mutedForeground),
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
    final columnWidths = <int, TableSize>{
      0: const FlexTableSize(),
    };
    if (isTeacher) {
      columnWidths[1] = const IntrinsicTableSize();
    } else {
      columnWidths[1] = const IntrinsicTableSize();
      columnWidths[2] = const IntrinsicTableSize();
      columnWidths[3] = const IntrinsicTableSize();
    }

    final headerCells = <TableCell>[
      TableCell(child: _buildSortCell(DeckSortField.title, 'Deck')),
    ];
    if (isTeacher) {
      headerCells
          .add(TableCell(child: _buildSortCell(DeckSortField.cards, 'Cards')));
    } else {
      headerCells
          .add(TableCell(child: _buildSortCell(DeckSortField.newCount, 'New')));
      headerCells.add(
          TableCell(child: _buildSortCell(DeckSortField.learning, 'Learning')));
      headerCells
          .add(TableCell(child: _buildSortCell(DeckSortField.due, 'Due')));
    }

    final rows = <TableRow>[
      TableHeader(cells: headerCells),
    ];

    for (final deck in decks) {
      final deckCells = <TableCell>[
        TableCell(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => isTeacher ? onTapDetail(deck) : onStudy(deck),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(deck.title, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ];
      if (isTeacher) {
        deckCells.add(TableCell(
          child: _buildCountCell(deck.totalCount ?? 0, colors.foreground),
        ));
      } else {
        deckCells.add(TableCell(
          child: _buildCountCell(deck.newCount ?? 0, const Color(0xFF3B82F6)),
        ));
        deckCells.add(TableCell(
          child: _buildCountCell(
            (deck.learningCount ?? 0) + (deck.relearningCount ?? 0),
            const Color(0xFFF97316),
          ),
        ));
        deckCells.add(TableCell(
          child: _buildCountCell(deck.dueCount ?? 0, const Color(0xFF22C55E)),
        ));
      }
      rows.add(TableRow(cells: deckCells));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: OutlinedContainer(
          child: Table(
            columnWidths: columnWidths,
            rows: rows,
          ),
        ),
      ),
    );
  }

  Widget _buildSortCell(DeckSortField field, String label) {
    final active = sort.field == field;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        sort.toggle(field);
        onSortChanged();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
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
                sort.ascending ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                size: 14,
                color: colors.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountCell(int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Text(
        value > 0 ? '$value' : '—',
        style: TextStyle(
          color: value > 0 ? color : colors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
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
