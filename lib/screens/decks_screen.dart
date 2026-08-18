import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/riverpod/auth_provider.dart';
import '../providers/riverpod/class_provider.dart';
import '../providers/riverpod/deck_provider.dart';
import '../providers/riverpod/card_store_provider.dart' as card_store;
import '../models/deck.dart';
import '../widgets/deck_tree.dart';
import '../widgets/narrow_app_bar.dart';
import '../widgets/responsive_dialog.dart';
import '../config/breakpoints.dart';
import 'deck_detail_screen.dart';
import 'study_screen.dart';

class DecksScreen extends ConsumerStatefulWidget {
  const DecksScreen({super.key});

  @override
  ConsumerState<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends ConsumerState<DecksScreen> {
  bool _initialLoadDone = false;
  bool _studyFullscreen = false;

  void _reloadDecks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(deckProvider.notifier).loadDecks();
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

  int? _selectedDetailId() {
    final detail = GoRouterState.of(context).uri.queryParameters['detail'];
    return detail != null ? int.tryParse(detail) : null;
  }

  int? _selectedStudyId() {
    final study = GoRouterState.of(context).uri.queryParameters['study'];
    return study != null ? int.tryParse(study) : null;
  }

  DeckResponse? _findDeck(int? id, List<DeckResponse> decks) {
    if (id == null) return null;
    return decks
        .cast<DeckResponse?>()
        .firstWhere((d) => d?.id == id, orElse: () => null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isTeacher = auth.role == 'teacher' || auth.role == 'admin';
    final colors = Theme.of(context).colorScheme;
    final provider = ref.watch(deckProvider);

    return Scaffold(
      child: Builder(
        builder: (context) {
          if (provider.isLoading && provider.decks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.decks.isEmpty) {
            return _errorView(context, provider, colors);
          }

          if (provider.decks.isEmpty) {
            return _emptyView(context, isTeacher, colors);
          }

          final detailId = _selectedDetailId();
          final studyId = _selectedStudyId();
          final selectedDeck = _findDeck(detailId ?? studyId, provider.decks);

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = MediaQuery.of(context).size.width;
              final isCompact = width < Breakpoints.medium;
              final listPaneSize = width >= Breakpoints.large
                  ? 360.0
                  : (width >= Breakpoints.expanded ? 320.0 : 280.0);

              // Build the embedded content widget
              Widget? embeddedContent;
              Widget? fullscreenContent;
              Widget? fullscreenStudyContent;
              if (selectedDeck != null) {
                if (isTeacher) {
                  embeddedContent = KeyedSubtree(
                    key: ValueKey(selectedDeck.id),
                    child: DeckDetailScreen(
                      deck: selectedDeck,
                      provider: ref.read(deckProvider.notifier),
                      classProvider: ref.read(classProvider.notifier),
                      onDeleted: () => context.go('/decks'),
                    ),
                  );
                  fullscreenContent = Scaffold(
                    headers: [
                      AppBar(
                        leading: [
                          IconButton.outline(
                            icon: const Icon(LucideIcons.arrowLeft, size: 20),
                            onPressed: () => context.go('/decks'),
                          ),
                        ],
                        title: Text(selectedDeck.title),
                      ),
                    ],
                    child: DeckDetailScreen(
                      deck: selectedDeck,
                      provider: ref.read(deckProvider.notifier),
                      classProvider: ref.read(classProvider.notifier),
                      onDeleted: () => context.go('/decks'),
                    ),
                  );
                } else {
                  embeddedContent = KeyedSubtree(
                    key: ValueKey(selectedDeck.id),
                    child: StudyScreen(
                      deckId: selectedDeck.id,
                      onClose: () => context.go('/decks'),
                      onFullscreen: width >= Breakpoints.medium
                          ? () => setState(() => _studyFullscreen = true)
                          : null,
                    ),
                  );
                  fullscreenContent = KeyedSubtree(
                    key: ValueKey(selectedDeck.id),
                    child: StudyScreen(
                      deckId: selectedDeck.id,
                      isFullscreen: true,
                      onClose: () => context.go('/decks'),
                    ),
                  );
                  fullscreenStudyContent = KeyedSubtree(
                    key: ValueKey(selectedDeck.id),
                    child: StudyScreen(
                      deckId: selectedDeck.id,
                      isFullscreen: true,
                      onClose: () => setState(() => _studyFullscreen = false),
                    ),
                  );
                }
              }

              // Study fullscreen toggle (only on dual-pane)
              if (_studyFullscreen &&
                  fullscreenStudyContent != null &&
                  !isTeacher &&
                  width >= Breakpoints.medium) {
                return fullscreenStudyContent;
              }

              // Compact: show selected content with back button
              if (isCompact && fullscreenContent != null) {
                return fullscreenContent;
              }

              // Compact with nothing selected: show deck list only
              if (isCompact) {
                return Column(
                  children: [
                    NarrowAppBar(
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
                              ref.read(deckProvider.notifier).loadDecks(),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _DeckTree(
                        decks: provider.decks,
                        isTeacher: isTeacher,
                        selectedId: detailId ?? studyId,
                        onSelect: (deck) {
                          if (isTeacher) {
                            context.go('/decks?detail=${deck.id}');
                          } else {
                            context.go('/decks?study=${deck.id}');
                          }
                        },
                        onDelete: isTeacher
                            ? (deck) => _confirmDelete(context, deck)
                            : null,
                        colors: colors,
                      ),
                    ),
                  ],
                );
              }

              // Medium or Expanded: show resizable dual pane
              return ResizablePanel.horizontal(
                draggerBuilder: (context) {
                  return const HorizontalResizableDragger();
                },
                children: [
                  ResizablePane(
                    initialSize: listPaneSize,
                    minSize: 200,
                    child: Column(
                      children: [
                        NarrowAppBar(
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
                                  ref.read(deckProvider.notifier).loadDecks(),
                            ),
                          ],
                        ),
                        Expanded(
                          child: _DeckTree(
                            decks: provider.decks,
                            isTeacher: isTeacher,
                            selectedId: detailId ?? studyId,
                            onSelect: (deck) {
                              if (isTeacher) {
                                context.go('/decks?detail=${deck.id}');
                              } else {
                                context.go('/decks?study=${deck.id}');
                              }
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
                    child: embeddedContent ??
                        const Center(
                          child: Text('Select a deck to view details'),
                        ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _errorView(
      BuildContext context, DeckState provider, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circleAlert, size: 48, color: colors.destructive),
          const SizedBox(height: 16),
          const Text('Failed to load decks'),
          const SizedBox(height: 8),
          Button.secondary(
            onPressed: () => ref.read(deckProvider.notifier).loadDecks(),
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
    showResponsiveDialog(
      context,
      builder: (ctx, _) {
        final provider = ref.read(deckProvider.notifier);
        return _DeckFormDialog(
          title: 'Create Deck',
          provider: provider,
          onSuccess: () => safeCloseOverlay(ctx),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, DeckResponse deck) {
    showResponsiveDialog(
      context,
      builder: (ctx, _) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('Delete "${deck.title}"? This cannot be undone.'),
        actions: [
          Button.ghost(
            onPressed: () => closeOverlay(ctx),
            child: const Text('Cancel'),
          ),
          Button.destructive(
            onPressed: () async {
              final ok =
                  await ref.read(deckProvider.notifier).deleteDeck(deck.id);
              if (ok && ctx.mounted) safeCloseOverlay(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DeckTree extends ConsumerStatefulWidget {
  final List<DeckResponse> decks;
  final bool isTeacher;
  final void Function(DeckResponse) onSelect;
  final int? selectedId;
  final void Function(DeckResponse)? onDelete;
  final ColorScheme colors;

  const _DeckTree({
    super.key,
    required this.decks,
    required this.isTeacher,
    required this.onSelect,
    this.selectedId,
    this.onDelete,
    required this.colors,
  });

  @override
  ConsumerState<_DeckTree> createState() => _DeckTreeState();
}

class _DeckTreeState extends ConsumerState<_DeckTree> {
  List<TreeNode<DeckResponse>> _treeNodes = [];

  void _buildNodes() {
    final root = buildDeckTree(widget.decks);
    final selectedId = widget.selectedId;
    List<TreeNode<DeckResponse>> convert(List<DeckNode> nodes) {
      return nodes
          .map((n) => TreeItemNode<DeckResponse>(
                data: n.deck,
                selected: n.deck.id == selectedId,
                expanded: true,
                children: convert(n.children),
              ))
          .toList();
    }

    setState(() {
      _treeNodes = convert(root);
    });
  }

  void deselectAll() {
    setState(() {
      _treeNodes = _treeNodes.deselectAll();
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
    if (oldWidget.decks != widget.decks ||
        oldWidget.selectedId != widget.selectedId) {
      _buildNodes();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildBadges(DeckResponse deck, card_store.CardStore cardStore) {
    final newCount = cardStore.deckNewCount(deck.id);
    final learnCount = cardStore.deckLearningCount(deck.id);
    final dueCount = cardStore.deckDueCount(deck.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isTeacher) ...[
          OutlineBadge(
            child: Text('${deck.totalCount ?? 0} cards',
                style: const TextStyle(fontSize: 12)),
          ),
        ] else ...[
          OutlineBadge(
            leading: const Icon(LucideIcons.sparkles, size: 12),
            child: Text('$newCount', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          OutlineBadge(
            leading: const Icon(LucideIcons.graduationCap, size: 12),
            child: Text('$learnCount', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          OutlineBadge(
            leading: const Icon(LucideIcons.clock, size: 12),
            child: Text('$dueCount', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
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
          // Subscribe to card store changes so badges re-render on updates.
          ref.watch(card_store.cardStoreProvider);
          final cardNotifier = ref.read(card_store.cardStoreProvider.notifier);
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
            trailing: _buildBadges(deck, cardNotifier),
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
  final DeckNotifier provider;
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
          onPressed: _isSubmitting ? null : () => closeOverlay(context),
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
