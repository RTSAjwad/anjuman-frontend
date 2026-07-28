import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/study_provider.dart';
import '../models/deck.dart';
import '../widgets/deck_tree.dart';
import '../widgets/shadcn_page_route.dart';
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
            if (isTeacher) ...[
              IconButton.outline(
                icon: const Icon(LucideIcons.plus, size: 20),
                onPressed: () => _showCreateDialog(context),
              ),
              IconButton.outline(
                icon: const Icon(LucideIcons.move, size: 20),
                onPressed: () => _showMoveDialog(context),
              ),
            ],
            IconButton.outline(
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

          final sorted = _sort.sort(provider.decks, (d, f) {
            return switch (f) {
              DeckSortField.title => d.title,
              DeckSortField.newCount => d.newCount ?? 0,
              DeckSortField.learning =>
                (d.learningCount ?? 0) + (d.relearningCount ?? 0),
              DeckSortField.due => d.dueCount ?? 0,
              DeckSortField.cards => d.totalCount ?? 0,
            };
          });

          return _DeckTreeTable(
            decks: sorted,
            isTeacher: isTeacher,
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

  void _showMoveDialog(BuildContext context) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) {
          final provider = context.read<DeckProvider>();
          return _MoveDeckDialog(
            provider: provider,
            onSuccess: () => Navigator.of(ctx).pop(),
          );
        },
      ),
    );
  }
}

class _DeckTreeTable extends StatefulWidget {
  final List<DeckResponse> decks;
  final bool isTeacher;
  final void Function(DeckResponse) onStudy;
  final void Function(DeckResponse) onTapDetail;
  final void Function(DeckResponse)? onDelete;
  final ColorScheme colors;

  const _DeckTreeTable({
    required this.decks,
    required this.isTeacher,
    required this.onStudy,
    required this.onTapDetail,
    this.onDelete,
    required this.colors,
  });

  @override
  State<_DeckTreeTable> createState() => _DeckTreeTableState();
}

class _DeckTreeTableState extends State<_DeckTreeTable> {
  final Set<int> _expandedIds = {};

  List<(DeckResponse, int)> _flattened() {
    final root = buildDeckTree(widget.decks);
    final result = <(DeckResponse, int)>[];
    void walk(List<DeckNode> nodes, int depth) {
      for (final node in nodes) {
        result.add((node.deck, depth));
        if (_expandedIds.contains(node.deck.id)) {
          walk(node.children, depth + 1);
        }
      }
    }

    for (final rootNode in root) {
      walk([rootNode], 0);
    }
    return result;
  }

  void _toggleExpand(int deckId) {
    setState(() {
      if (_expandedIds.contains(deckId)) {
        _expandedIds.remove(deckId);
      } else {
        _expandedIds.add(deckId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final flat = _flattened();

    final headerCells = <TableCell>[
      TableCell(child: _buildHeaderCell('Deck')),
    ];
    if (widget.isTeacher) {
      headerCells
          .add(TableCell(child: _buildHeaderCell('Cards', alignRight: true)));
    } else {
      headerCells
          .add(TableCell(child: _buildHeaderCell('New', alignRight: true)));
      headerCells.add(
          TableCell(child: _buildHeaderCell('Learning', alignRight: true)));
      headerCells
          .add(TableCell(child: _buildHeaderCell('Due', alignRight: true)));
    }

    final rows = <TableRow>[
      TableHeader(cells: headerCells),
    ];

    for (final (deck, _) in flat) {
      final hasChildren = widget.decks.any((d) => d.parentId == deck.id);
      final isExpanded = _expandedIds.contains(deck.id);

      final deckCells = <TableCell>[
        TableCell(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.isTeacher
                ? widget.onTapDetail(deck)
                : widget.onStudy(deck),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasChildren)
                    GestureDetector(
                      onTap: () => _toggleExpand(deck.id),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: isExpanded ? 0.25 : 0,
                        child: Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: widget.colors.mutedForeground,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 24),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      deck.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
      if (widget.isTeacher) {
        deckCells.add(TableCell(
          child: _buildCountCell(deck.totalCount ?? 0, widget.colors.foreground,
              alignRight: true),
        ));
      } else {
        deckCells.add(TableCell(
          child: _buildCountCell(deck.newCount ?? 0, const Color(0xFF3B82F6),
              alignRight: true),
        ));
        deckCells.add(TableCell(
          child: _buildCountCell(
            (deck.learningCount ?? 0) + (deck.relearningCount ?? 0),
            const Color(0xFFF97316),
            alignRight: true,
          ),
        ));
        deckCells.add(TableCell(
          child: _buildCountCell(deck.dueCount ?? 0, const Color(0xFF22C55E),
              alignRight: true),
        ));
      }
      rows.add(TableRow(cells: deckCells));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: OutlinedContainer(
          child: Table(
            columnWidths: <int, TableSize>{
              0: const FlexTableSize(),
              for (var i = 1; i <= (widget.isTeacher ? 1 : 3); i++)
                i: const IntrinsicTableSize(),
            },
            rows: rows,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, {bool alignRight = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: alignRight ? Alignment.centerRight : null,
      child: Text(label).muted().semiBold(),
    );
  }

  Widget _buildCountCell(int value, Color color, {bool alignRight = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: alignRight ? Alignment.centerRight : Alignment.center,
      child: Text(
        value > 0 ? '$value' : '—',
        style: TextStyle(
          color: value > 0 ? color : widget.colors.mutedForeground,
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
  int? _selectedParentId;
  bool _isSubmitting = false;
  String? _error;

  List<(DeckResponse, int)> _flattenedDecks() {
    final root = buildDeckTree(widget.provider.decks);
    final result = <(DeckResponse, int)>[];
    void walk(List<DeckNode> nodes, int depth) {
      for (final node in nodes) {
        result.add((node.deck, depth));
        walk(node.children, depth + 1);
      }
    }

    for (final rootNode in root) {
      walk([rootNode], 0);
    }
    return result;
  }

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
      parentId: _selectedParentId,
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
    final flatDecks = _flattenedDecks();

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
            const SizedBox(height: 16),
            if (flatDecks.isNotEmpty) ...[
              const Text('Parent Deck (optional)',
                      style: TextStyle(fontSize: 13))
                  .semiBold(),
              const SizedBox(height: 6),
              Select<DeckResponse>(
                value: _selectedParentId != null
                    ? flatDecks
                        .firstWhere((d) => d.$1.id == _selectedParentId)
                        .$1
                    : null,
                placeholder: const Text('None (top-level)'),
                onChanged: (value) {
                  setState(() => _selectedParentId = value?.id);
                },
                itemBuilder: (context, deck) {
                  final entry = flatDecks.firstWhere((d) => d.$1.id == deck.id);
                  final indent = '  ' * entry.$2;
                  return Text('$indent${deck.title}',
                      overflow: TextOverflow.ellipsis);
                },
                popup: SelectPopup(
                  items: SelectItemList(children: [
                    for (final (deck, depth) in flatDecks)
                      SelectItemButton(
                        value: deck,
                        child: Text(
                          '${'  ' * depth}${deck.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ]),
                ),
              ),
            ],
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

class _MoveDeckDialog extends StatefulWidget {
  final DeckProvider provider;
  final VoidCallback onSuccess;

  const _MoveDeckDialog({
    required this.provider,
    required this.onSuccess,
  });

  @override
  State<_MoveDeckDialog> createState() => _MoveDeckDialogState();
}

class _MoveDeckDialogState extends State<_MoveDeckDialog> {
  DeckResponse? _selectedDeck;
  int? _targetParentId;
  bool _isSubmitting = false;
  String? _error;

  List<(DeckResponse, int)> _flattenedDecks() {
    final root = buildDeckTree(widget.provider.decks);
    final result = <(DeckResponse, int)>[];
    void walk(List<DeckNode> nodes, int depth) {
      for (final node in nodes) {
        result.add((node.deck, depth));
        walk(node.children, depth + 1);
      }
    }

    for (final rootNode in root) {
      walk([rootNode], 0);
    }
    return result;
  }

  Future<void> _submit() async {
    if (_selectedDeck == null) {
      setState(() => _error = 'Please select a deck to move');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final ok = await widget.provider.moveDeck(
      _selectedDeck!.id,
      parentId: _targetParentId,
    );

    if (mounted) {
      if (ok) {
        widget.onSuccess();
      } else {
        setState(() {
          _isSubmitting = false;
          _error = widget.provider.error ?? 'Failed to move deck';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final flatDecks = _flattenedDecks();

    return AlertDialog(
      title: const Text('Move Deck'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select deck to move', style: TextStyle(fontSize: 13))
                .semiBold(),
            const SizedBox(height: 6),
            Select<DeckResponse>(
              value: _selectedDeck,
              placeholder: const Text('Choose a deck...'),
              onChanged: (value) {
                setState(() => _selectedDeck = value);
              },
              itemBuilder: (context, deck) {
                final entry = flatDecks.firstWhere((d) => d.$1.id == deck.id);
                final indent = '  ' * entry.$2;
                return Text('$indent${deck.title}',
                    overflow: TextOverflow.ellipsis);
              },
              popup: SelectPopup(
                items: SelectItemList(children: [
                  for (final (deck, depth) in flatDecks)
                    SelectItemButton(
                      value: deck,
                      child: Text(
                        '${'  ' * depth}${deck.title}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Move into (optional, none = top-level)',
                    style: TextStyle(fontSize: 13))
                .semiBold(),
            const SizedBox(height: 6),
            Select<DeckResponse?>(
              value: _targetParentId != null
                  ? flatDecks.firstWhere((d) => d.$1.id == _targetParentId).$1
                  : null,
              placeholder: const Text('None (top-level)'),
              onChanged: (value) {
                setState(() => _targetParentId = value?.id);
              },
              itemBuilder: (context, deck) {
                if (deck == null) return const Text('None (top-level)');
                final entry = flatDecks.firstWhere((d) => d.$1.id == deck.id);
                final indent = '  ' * entry.$2;
                return Text('$indent${deck.title}',
                    overflow: TextOverflow.ellipsis);
              },
              popup: SelectPopup(
                items: SelectItemList(children: [
                  const SelectItemButton<DeckResponse?>(
                    value: null,
                    child: Text('None (top-level)'),
                  ),
                  for (final (deck, depth) in flatDecks)
                    SelectItemButton<DeckResponse?>(
                      value: deck,
                      child: Text(
                        '${'  ' * depth}${deck.title}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ]),
              ),
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
              : const Text('Move'),
        ),
      ],
    );
  }
}
