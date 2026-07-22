import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/deck_provider.dart';
import '../models/deck.dart';
import '../models/class_info.dart';
import '../models/search_result.dart';
import '../services/user_service.dart';

class DeckDetailScreen extends StatefulWidget {
  final DeckResponse deck;
  final DeckProvider provider;
  final ClassProvider classProvider;

  const DeckDetailScreen({
    super.key,
    required this.deck,
    required this.provider,
    required this.classProvider,
  });

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  late String _deckTitle;
  DeckDetailResponse? _detail;
  List<NoteResponse> _notes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _deckTitle = widget.deck.title;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final detail = await widget.provider.loadDeckDetail(widget.deck.id);
    if (detail == null) {
      setState(() {
        _isLoading = false;
        _error = widget.provider.error ?? 'Failed to load';
      });
      return;
    }

    final notes = await widget.provider.listNotes(widget.deck.id) ?? [];

    setState(() {
      _detail = detail;
      _notes = notes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.user?.id == widget.deck.createdBy;
    final isAdmin = auth.role == 'admin';
    final canManage = isOwner || isAdmin;
    final isTeacher = auth.role == 'teacher' || isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(_deckTitle),
        actions: [
          if (isTeacher)
            PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'rename':
                    _showRenameDialog(context);
                  case 'duplicate':
                    widget.provider.duplicateDeck(widget.deck.id);
                    _load();
                  case 'delete':
                    _confirmDeleteDeck(context);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Rename'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 20),
                      SizedBox(width: 8),
                      Text('Duplicate'),
                    ],
                  ),
                ),
                if (canManage)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Deck',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null || _detail == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(_error ?? 'Failed to load deck details',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final detail = _detail!;
          final notes = _notes;

          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Deck info
                  _DeckInfoCard(
                    deck: widget.deck,
                    collaborators: detail.collaborators,
                    classes: detail.classes,
                    canManage: canManage,
                    onAddCollaborator: () => _showShareDialog(context),
                    onRemoveCollaborator: (userId) =>
                        _confirmUnshare(context, userId),
                    onTransfer: () => _showTransferOwnerDialog(context),
                    onAddToClass: () => _showAddToClassDialog(context),
                    onRemoveFromClass: (classId) =>
                        _confirmRemoveFromClass(context, classId),
                    provider: widget.provider,
                  ),
                  const SizedBox(height: 24),

                  // Notes section
                  Row(
                    children: [
                      Text('Notes',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${notes.length} total',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      if (isTeacher) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _showCreateNoteDialog(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Note'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _showManageNoteTypesDialog(context),
                          icon: const Icon(Icons.category, size: 18),
                          label: const Text('Manage types'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (notes.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            canManage ? 'Add your first note' : 'No notes yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: const Row(
                              children: [
                                Expanded(
                                    flex: 5,
                                    child: Text('Front',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12))),
                                Expanded(
                                    flex: 5,
                                    child: Text('Back',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Type',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Cards',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12))),
                                SizedBox(width: 80),
                              ],
                            ),
                          ),
                          ...notes.map((note) => _NoteRow(
                                note: note,
                                canManage: isTeacher,
                                onEdit: () =>
                                    _showEditNoteDialog(context, note),
                                onDelete: () =>
                                    _confirmDeleteNote(context, note),
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateNoteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _NoteFormDialog(
        deckId: widget.deck.id,
        provider: widget.provider,
        onSuccess: () {
          Navigator.of(ctx).pop();
          _load();
        },
      ),
    );
  }

  void _showManageNoteTypesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _NoteTypeManageDialog(
        provider: widget.provider,
        onCreated: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showEditNoteDialog(BuildContext context, NoteResponse note) {
    showDialog(
      context: context,
      builder: (ctx) => _NoteFormDialog(
        deckId: widget.deck.id,
        provider: widget.provider,
        existingNote: note,
        onSuccess: () {
          Navigator.of(ctx).pop();
          _load();
        },
      ),
    );
  }

  void _confirmDeleteNote(BuildContext context, NoteResponse note) {
    final front = (note.fields['Front'] ?? '').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content:
            Text('Delete "$front"? All cards for this note will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final ok =
                  await widget.provider.deleteNote(widget.deck.id, note.id);
              if (ok && ctx.mounted) {
                Navigator.of(ctx).pop();
                _load();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTransferOwnerDialog(BuildContext context) {
    final service = UserService(widget.provider.apiClient);
    int? selectedUserId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Transfer Ownership'),
          content: SizedBox(
            width: 400,
            child: DropdownSearch<SearchResult>(
              items: (filter, _) async => service.searchUsers(filter),
              compareFn: (a, b) => a.id == b.id,
              itemAsString: (u) => '${u.displayName} ${u.email}',
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchDelay: const Duration(milliseconds: 300),
                itemBuilder: (ctx, user, isDisabled, isSelected) {
                  return ListTile(
                    title: Text(user.displayName),
                    subtitle: Text(user.email),
                  );
                },
              ),
              onSelected: (user) {
                setDialogState(() => selectedUserId = user?.id);
              },
              decoratorProps: const DropDownDecoratorProps(
                decoration: InputDecoration(
                  labelText: 'New owner',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedUserId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a teacher'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final ok = await widget.provider
                    .transferOwner(widget.deck.id, selectedUserId!);
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                  _load();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(widget.provider.error ??
                          'Failed to transfer ownership'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    final service = UserService(widget.provider.apiClient);
    int? selectedUserId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Share Deck'),
          content: SizedBox(
            width: 400,
            child: DropdownSearch<SearchResult>(
              items: (filter, _) async => service.searchUsers(filter),
              compareFn: (a, b) => a.id == b.id,
              itemAsString: (u) => '${u.displayName} ${u.email}',
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchDelay: const Duration(milliseconds: 300),
                itemBuilder: (ctx, user, isDisabled, isSelected) {
                  return ListTile(
                    title: Text(user.displayName),
                    subtitle: Text(user.email),
                  );
                },
              ),
              onSelected: (user) {
                setDialogState(() => selectedUserId = user?.id);
              },
              decoratorProps: const DropDownDecoratorProps(
                decoration: InputDecoration(
                  labelText: 'Search teacher',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedUserId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a user'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final ok = await widget.provider
                    .shareDeck(widget.deck.id, selectedUserId!);
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                  _load();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content:
                          Text(widget.provider.error ?? 'Failed to share deck'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Share'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnshare(BuildContext context, int userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: const Text('Remove this teacher from the deck collaborators?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final ok =
                  await widget.provider.unshareDeck(widget.deck.id, userId);
              if (ok && ctx.mounted) {
                Navigator.of(ctx).pop();
                _load();
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddToClassDialog(BuildContext context) {
    final classes = widget.classProvider.classes;
    int? selectedClassId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add to Class'),
          content: SizedBox(
            width: 300,
            child: DropdownButtonFormField<int>(
              initialValue: null,
              hint: const Text('Select class'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: classes
                  .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setDialogState(() => selectedClassId = v),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedClassId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a class'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final ok = await widget.provider
                    .addDeckToClass(widget.deck.id, selectedClassId!);
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                  _load();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(widget.provider.error ??
                          'Failed to add deck to class'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveFromClass(BuildContext context, int classId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Class'),
        content: const Text('Remove this deck from the class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final ok = await widget.provider
                  .removeDeckFromClass(widget.deck.id, classId);
              if (ok && ctx.mounted) {
                Navigator.of(ctx).pop();
                _load();
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: _deckTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Deck'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final ok = await widget.provider
                  .renameDeck(widget.deck.id, controller.text.trim());
              if (ok && ctx.mounted) {
                setState(() => _deckTitle = controller.text.trim());
                Navigator.of(ctx).pop();
                _load();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDeck(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('Delete "${widget.deck.title}"? '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final ok = await widget.provider.deleteDeck(widget.deck.id);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DeckInfoCard extends StatefulWidget {
  final DeckResponse deck;
  final List<CollaboratorResponse> collaborators;
  final List<ClassInfo> classes;
  final bool canManage;
  final VoidCallback onAddCollaborator;
  final void Function(int userId) onRemoveCollaborator;
  final VoidCallback onTransfer;
  final VoidCallback onAddToClass;
  final void Function(int classId) onRemoveFromClass;
  final DeckProvider provider;

  const _DeckInfoCard({
    required this.deck,
    required this.collaborators,
    required this.classes,
    required this.canManage,
    required this.onAddCollaborator,
    required this.onRemoveCollaborator,
    required this.onTransfer,
    required this.onAddToClass,
    required this.onRemoveFromClass,
    required this.provider,
  });

  @override
  State<_DeckInfoCard> createState() => _DeckInfoCardState();
}

class _DeckInfoCardState extends State<_DeckInfoCard> {
  bool _isEditingDesc = false;
  late TextEditingController _descController;
  bool _isSavingDesc = false;

  @override
  void initState() {
    super.initState();
    _descController =
        TextEditingController(text: widget.deck.description ?? '');
  }

  @override
  void didUpdateWidget(covariant _DeckInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deck.description != widget.deck.description) {
      _descController.text = widget.deck.description ?? '';
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveDescription() async {
    final text = _descController.text.trim();
    setState(() => _isSavingDesc = true);
    final result =
        await widget.provider.updateDeck(widget.deck.id, description: text);
    if (mounted) {
      setState(() {
        _isSavingDesc = false;
        if (result != null) {
          _isEditingDesc = false;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(widget.provider.error ?? 'Failed to save description'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTeacher = widget.canManage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            Row(
              children: [
                Expanded(
                  child: _isEditingDesc
                      ? TextField(
                          controller: _descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Deck description...',
                          ),
                        )
                      : widget.deck.description != null &&
                              widget.deck.description!.isNotEmpty
                          ? Text(widget.deck.description!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant))
                          : isTeacher
                              ? Text('Add a description',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant))
                              : const SizedBox.shrink(),
                ),
                if (isTeacher)
                  _isEditingDesc
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, size: 18),
                              tooltip: 'Save',
                              onPressed:
                                  _isSavingDesc ? null : _saveDescription,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Cancel',
                              onPressed: () {
                                setState(() {
                                  _isEditingDesc = false;
                                  _descController.text =
                                      widget.deck.description ?? '';
                                });
                              },
                            ),
                          ],
                        )
                      : IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit description',
                          onPressed: () =>
                              setState(() => _isEditingDesc = true),
                        ),
              ],
            ),
            const SizedBox(height: 16),

            // Owner
            Row(
              children: [
                Text('Owner',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (widget.canManage) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onTransfer,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Transfer'),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  CircleAvatar(
                      radius: 12,
                      child: Text(
                          widget.deck.ownerFirstName?.isNotEmpty == true
                              ? widget.deck.ownerFirstName![0].toUpperCase()
                              : widget.deck.createdBy.toString()[0],
                          style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.deck.ownerDisplayName,
                          style: theme.textTheme.bodyMedium),
                      if (widget.deck.ownerEmail != null &&
                          widget.deck.ownerDisplayName !=
                              widget.deck.ownerEmail)
                        Text(widget.deck.ownerEmail!,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Collaborators
            if (widget.collaborators.isNotEmpty || widget.canManage) ...[
              Row(
                children: [
                  Text('Collaborators',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (widget.canManage) ...[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.onAddCollaborator,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Share'),
                    ),
                  ],
                ],
              ),
              if (widget.collaborators.isNotEmpty)
                ...widget.collaborators.map((c) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                              radius: 12,
                              child: Text(
                                  c.firstName.isNotEmpty
                                      ? c.firstName[0].toUpperCase()
                                      : c.email[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 12))),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  c.displayName.isNotEmpty
                                      ? c.displayName
                                      : c.email,
                                  style: theme.textTheme.bodyMedium),
                              if (c.displayName.isNotEmpty)
                                Text(c.email,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                            ],
                          ),
                          const Spacer(),
                          if (widget.canManage)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 18),
                              color: theme.colorScheme.error,
                              tooltip: 'Remove',
                              onPressed: () =>
                                  widget.onRemoveCollaborator(c.userId),
                            ),
                        ],
                      ),
                    ))
              else if (widget.canManage)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Not shared with anyone yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
            ],
            // Classes
            if (widget.canManage || widget.classes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Assigned Classes',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (widget.canManage) ...[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.onAddToClass,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ],
              ),
              if (widget.classes.isNotEmpty)
                ...widget.classes.map((c) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.group, size: 18),
                          const SizedBox(width: 8),
                          Text(c.name, style: theme.textTheme.bodyMedium),
                          const Spacer(),
                          if (widget.canManage)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 18),
                              color: theme.colorScheme.error,
                              tooltip: 'Remove',
                              onPressed: () => widget.onRemoveFromClass(c.id),
                            ),
                        ],
                      ),
                    ))
              else if (widget.canManage)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Not assigned to any class',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final NoteResponse note;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteRow({
    required this.note,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Get the front/back from the first card's rendered text
    final front = note.cards.isNotEmpty ? note.cards.first.front : '';
    final back = note.cards.isNotEmpty ? note.cards.first.back : '';

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
            flex: 5,
            child: Text(
              front,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              back.replaceAll(RegExp(r'<[^>]*>'), ' ').trim(),
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              note.noteTypeName,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${note.cards.length}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (canManage)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: theme.colorScheme.error,
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NoteFormDialog extends StatefulWidget {
  final int deckId;
  final DeckProvider provider;
  final NoteResponse? existingNote;
  final VoidCallback onSuccess;

  const _NoteFormDialog({
    required this.deckId,
    required this.provider,
    this.existingNote,
    required this.onSuccess,
  });

  @override
  State<_NoteFormDialog> createState() => _NoteFormDialogState();
}

class _NoteFormDialogState extends State<_NoteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _loadingTypes = true;

  List<NoteType> _noteTypes = [];
  NoteType? _selectedType;
  final Map<String, TextEditingController> _fieldControllers = {};

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    _loadNoteTypes();
  }

  Future<void> _loadNoteTypes() async {
    await widget.provider.loadNoteTypes();
    if (!mounted) return;
    setState(() {
      _noteTypes = widget.provider.noteTypes;
      _loadingTypes = false;

      if (_isEditing && widget.existingNote != null) {
        // Find the note type used by the existing note
        _selectedType = _noteTypes.cast<NoteType?>().firstWhere(
              (t) => t!.id == widget.existingNote!.noteTypeId,
              orElse: () => _noteTypes.isNotEmpty ? _noteTypes.first : null,
            );
        // Populate field controllers from existing fields
        if (_selectedType != null) {
          _initFieldControllers(_selectedType!.fieldNames);
          for (final name in _selectedType!.fieldNames) {
            _fieldControllers[name]?.text =
                (widget.existingNote!.fields[name] ?? '').toString();
          }
        }
      } else if (_noteTypes.isNotEmpty) {
        _selectedType = _noteTypes.first;
        _initFieldControllers(_selectedType!.fieldNames);
      }
    });
  }

  void _initFieldControllers(List<String> fieldNames) {
    _disposeControllers();
    for (final name in fieldNames) {
      _fieldControllers[name] = TextEditingController();
    }
  }

  void _onTypeChanged(NoteType? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      _initFieldControllers(type.fieldNames);
    });
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    _fieldControllers.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) return;

    setState(() => _isSubmitting = true);

    final fields = {
      for (final e in _fieldControllers.entries) e.key: e.value.text.trim(),
    };

    final ok = _isEditing
        ? await widget.provider.updateNote(
            widget.deckId,
            widget.existingNote!.id,
            UpdateNote(fields: fields),
          )
        : await widget.provider
            .createNote(widget.deckId, _selectedType!.id, fields);

    if (mounted) {
      if (ok != null) {
        widget.onSuccess();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.provider.error ?? 'Operation failed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTypes) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Note' : 'Create Note'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<NoteType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Note type',
                border: OutlineInputBorder(),
              ),
              items: _noteTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: _isEditing ? null : _onTypeChanged,
            ),
            if (_selectedType != null) ...[
              const SizedBox(height: 16),
              for (final name in _selectedType!.fieldNames)
                Padding(
                  padding: EdgeInsets.only(
                      top: _selectedType!.fieldNames.first == name ? 0 : 16),
                  child: TextFormField(
                    controller: _fieldControllers[name],
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: name,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '$name is required';
                      }
                      return null;
                    },
                  ),
                ),
            ],
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
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _NoteTypeManageDialog extends StatefulWidget {
  final DeckProvider provider;
  final VoidCallback onCreated;

  const _NoteTypeManageDialog({
    required this.provider,
    required this.onCreated,
  });

  @override
  State<_NoteTypeManageDialog> createState() => _NoteTypeManageDialogState();
}

class _NoteTypeManageDialogState extends State<_NoteTypeManageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fieldNamesController = TextEditingController();
  final _templateNameController = TextEditingController();
  final _frontPatternController = TextEditingController();
  final _backPatternController = TextEditingController();
  bool _isSubmitting = false;
  final List<_TemplateEntry> _templates = [];

  @override
  void initState() {
    super.initState();
    widget.provider.loadNoteTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fieldNamesController.dispose();
    _templateNameController.dispose();
    _frontPatternController.dispose();
    _backPatternController.dispose();
    super.dispose();
  }

  void _addTemplate() {
    final name = _templateNameController.text.trim();
    final front = _frontPatternController.text.trim();
    final back = _backPatternController.text.trim();
    if (name.isEmpty || front.isEmpty || back.isEmpty) return;
    setState(() {
      _templates.add(_TemplateEntry(
        name: name,
        frontPattern: front,
        backPattern: back,
      ));
      _templateNameController.clear();
      _frontPatternController.clear();
      _backPatternController.clear();
    });
  }

  void _removeTemplate(int index) {
    setState(() => _templates.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one template'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final fieldNames = _fieldNamesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final noteType = CreateNoteType(
      name: _nameController.text.trim(),
      fieldNames: fieldNames,
      templates: _templates
          .map((t) => CreateNoteTemplate(
                name: t.name,
                frontPattern: t.frontPattern,
                backPattern: t.backPattern,
              ))
          .toList(),
    );

    final ok = await widget.provider.createNoteType(noteType);
    if (mounted) {
      if (ok) {
        widget.onCreated();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(widget.provider.error ?? 'Failed to create note type'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteTypes = widget.provider.noteTypes;

    return AlertDialog(
      title: const Text('Manage Note Types'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (noteTypes.isNotEmpty) ...[
              Text('Existing types',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...noteTypes.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('${t.name} (${t.fieldNames.join(", ")})',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  )),
              const Divider(),
              const SizedBox(height: 8),
            ],
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Basic, Cloze',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fieldNamesController,
                    decoration: const InputDecoration(
                      labelText: 'Field names',
                      hintText: 'e.g. Front, Back',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Templates',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _templateNameController,
                    decoration: const InputDecoration(
                      labelText: 'Template name',
                      hintText: 'e.g. Forward',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _frontPatternController,
                    decoration: const InputDecoration(
                      labelText: 'Front pattern',
                      hintText: 'e.g. {{Front}}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _backPatternController,
                    decoration: const InputDecoration(
                      labelText: 'Back pattern',
                      hintText: 'e.g. {{Back}}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addTemplate,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add template'),
                  ),
                  if (_templates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._templates.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${e.value.name}: ${e.value.frontPattern} / ${e.value.backPattern}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => _removeTemplate(e.key),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
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

class _TemplateEntry {
  final String name;
  final String frontPattern;
  final String backPattern;

  const _TemplateEntry({
    required this.name,
    required this.frontPattern,
    required this.backPattern,
  });
}
