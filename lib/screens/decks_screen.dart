import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/study_provider.dart';
import '../models/deck.dart';
import '../widgets/deck_tree.dart';
import 'deck_detail_screen.dart';
import 'study_screen.dart';

class DecksScreen extends StatefulWidget {
  const DecksScreen({super.key});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  bool _initialLoadDone = false;
  DeckResponse? _selectedDeck;

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

          return ResizablePanel.horizontal(
            draggerBuilder: (context) {
              return const HorizontalResizableDragger();
            },
            children: [
              ResizablePane(
                initialSize: 300,
                minSize: 200,
                child: Column(
                  children: [
                    AppBar(
                      title: const Text('Decks'),
                      trailing: [
                        if (isTeacher)
                          IconButton.outline(
                            icon: const Icon(LucideIcons.plus, size: 20),
                            onPressed: () => _showCreateDialog(context),
                          ),
                        IconButton.outline(
                          icon: const Icon(LucideIcons.refreshCw, size: 20),
                          onPressed: () =>
                              context.read<DeckProvider>().loadDecks(),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _DeckTree(
                        decks: provider.decks,
                        isTeacher: isTeacher,
                        onSelect: (deck) {
                          setState(() => _selectedDeck = deck);
                        },
                        onDelete: isTeacher
                            ? (deck) => _confirmDelete(context, deck)
                            : null,
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ),
              ResizablePane.flex(
                child: _selectedDeck != null
                    ? isTeacher
                        ? KeyedSubtree(
                            key: ValueKey(_selectedDeck!.id),
                            child: DeckDetailScreen(
                              deck: _selectedDeck!,
                              provider: provider,
                              classProvider: context.read<ClassProvider>(),
                              showBackButton: false,
                              onDeleted: () {
                                setState(() => _selectedDeck = null);
                              },
                            ),
                          )
                        : KeyedSubtree(
                            key: ValueKey(_selectedDeck!.id),
                            child: StudyScreen(
                              deckId: _selectedDeck!.id,
                              provider: context.read<StudyProvider>(),
                              embedded: true,
                            ),
                          )
                    : const Center(
                        child: Text('Select a deck to view details'),
                      ),
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

class _DeckTree extends StatefulWidget {
  final List<DeckResponse> decks;
  final bool isTeacher;
  final void Function(DeckResponse) onSelect;
  final void Function(DeckResponse)? onDelete;
  final ColorScheme colors;

  const _DeckTree({
    required this.decks,
    required this.isTeacher,
    required this.onSelect,
    this.onDelete,
    required this.colors,
  });

  @override
  State<_DeckTree> createState() => _DeckTreeState();
}

class _DeckTreeState extends State<_DeckTree> {
  List<TreeNode<DeckResponse>> _treeNodes = [];

  void _buildNodes() {
    final root = buildDeckTree(widget.decks);
    List<TreeNode<DeckResponse>> convert(List<DeckNode> nodes) {
      return nodes
          .map((n) => TreeItemNode<DeckResponse>(
                data: n.deck,
                expanded: true,
                children: convert(n.children),
              ))
          .toList();
    }

    setState(() {
      _treeNodes = convert(root);
    });
  }

  @override
  void initState() {
    super.initState();
    _buildNodes();
  }

  @override
  void didUpdateWidget(covariant _DeckTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decks != widget.decks) {
      _buildNodes();
    }
  }

  Widget _buildBadges(DeckResponse deck) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isTeacher) ...[
          OutlineBadge(
            child: Text('${deck.totalCount ?? 0} cards',
                style: const TextStyle(fontSize: 12)),
          ),
        ] else ...[
          if ((deck.newCount ?? 0) > 0)
            OutlineBadge(
              child: Text('${deck.newCount}',
                  style: const TextStyle(fontSize: 12)),
            ),
          if ((deck.learningCount ?? 0) + (deck.relearningCount ?? 0) > 0)
            OutlineBadge(
              child: Text(
                  '${(deck.learningCount ?? 0) + (deck.relearningCount ?? 0)}',
                  style: const TextStyle(fontSize: 12)),
            ),
          if ((deck.dueCount ?? 0) > 0)
            OutlineBadge(
              child: Text('${deck.dueCount}',
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(radius: () => 0),
      child: Tree<DeckResponse>(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        recursiveSelection: false,
        nodes: _treeNodes,
        branchLine: BranchLine.line,
        onSelectionChanged: (selectedNodes, multiSelect, selected) {
          if (selected) {
            setState(() {
              _treeNodes = _treeNodes.setSelectedNodes(selectedNodes);
            });
            final deck =
                (selectedNodes.first as TreeItemNode<DeckResponse>).data;
            widget.onSelect(deck);
          }
        },
        builder: (context, node) {
          final deck = node.data;
          final hasChildren = node.children.isNotEmpty;
          return TreeItem(
            onPressed: () {},
            onExpand: hasChildren
                ? Tree.defaultItemExpandHandler(
                    _treeNodes,
                    node,
                    (value) {
                      setState(() => _treeNodes = value);
                    },
                  )
                : null,
            trailing: _buildBadges(deck),
            child: Text(
              deck.title,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }
}

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
