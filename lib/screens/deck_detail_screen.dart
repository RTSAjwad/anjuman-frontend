import 'package:flutter/material.dart'
    show Colors, ScaffoldMessenger, SnackBar, SnackBarBehavior, StatefulBuilder;
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/deck_provider.dart';
import '../models/deck.dart';
import '../models/class_info.dart';
import '../models/search_result.dart';
import '../services/user_service.dart';
import '../widgets/shadcn_search_dropdown.dart';

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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(_deckTitle),
          trailing: [
            if (isTeacher)
              IconButton.ghost(
                icon: const Icon(LucideIcons.pencil, size: 20),
                onPressed: () => _showRenameDialog(context),
              ),
            if (isTeacher)
              IconButton.ghost(
                icon: const Icon(LucideIcons.copy, size: 20),
                onPressed: () => _confirmDuplicate(context),
              ),
            if (isTeacher && canManage)
              IconButton.ghost(
                icon: const Icon(LucideIcons.trash2, size: 20),
                onPressed: () => _confirmDeleteDeck(context),
              ),
          ],
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _detail == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.circleAlert,
                          size: 48, color: colors.destructive),
                      const SizedBox(height: 16),
                      Text(_error ?? 'Failed to load deck details'),
                      const SizedBox(height: 8),
                      Button.secondary(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(
                  context, _detail!, _notes, canManage, isTeacher, colors),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DeckDetailResponse detail,
    List<NoteResponse> notes,
    bool canManage,
    bool isTeacher,
    ColorScheme colors,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeckInfoCard(
            deck: widget.deck,
            collaborators: detail.collaborators,
            classes: detail.classes,
            canManage: canManage,
            onAddCollaborator: () => _showShareDialog(context),
            onRemoveCollaborator: (userId) => _confirmUnshare(context, userId),
            onTransfer: () => _showTransferOwnerDialog(context),
            onAddToClass: () => _showAddToClassDialog(context),
            onRemoveFromClass: (classId) =>
                _confirmRemoveFromClass(context, classId),
            provider: widget.provider,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Notes').semiBold(),
              const Spacer(),
              Text('${notes.length} total',
                  style:
                      TextStyle(color: colors.mutedForeground, fontSize: 13)),
              if (isTeacher) ...[
                const SizedBox(width: 8),
                Button.secondary(
                  leading: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => _showCreateNoteDialog(context),
                  child: const Text('Add Note'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            OutlinedContainer(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  canManage ? 'Add your first note' : 'No notes yet',
                  style: TextStyle(color: colors.mutedForeground),
                ),
              ),
            )
          else
            OutlinedContainer(
              child: Table(
                columnWidths: {
                  0: const FlexTableSize(),
                  1: const FlexTableSize(),
                  2: const IntrinsicTableSize(),
                  3: const IntrinsicTableSize(),
                  if (isTeacher) 4: const IntrinsicTableSize(),
                },
                rows: [
                  TableHeader(cells: [
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('Front',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('Back',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('Type',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('Cards',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    if (isTeacher)
                      const TableCell(
                        child: SizedBox(width: 80),
                      ),
                  ]),
                  for (final note in notes)
                    TableRow(cells: [
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            note.cards.isNotEmpty ? note.cards.first.front : '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            (note.cards.isNotEmpty ? note.cards.first.back : '')
                                .replaceAll(RegExp(r'<[^>]*>'), ' ')
                                .trim(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Text(note.noteTypeName,
                              style: TextStyle(color: colors.mutedForeground),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Text('${note.cards.length}',
                              style: TextStyle(color: colors.mutedForeground)),
                        ),
                      ),
                      if (isTeacher)
                        TableCell(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.ghost(
                                icon: const Icon(LucideIcons.pencil, size: 18),
                                onPressed: () =>
                                    _showEditNoteDialog(context, note),
                              ),
                              IconButton.ghost(
                                icon: const Icon(LucideIcons.trash2,
                                    size: 18, color: Colors.red),
                                onPressed: () =>
                                    _confirmDeleteNote(context, note),
                              ),
                            ],
                          ),
                        ),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateNoteDialog(BuildContext context) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => _NoteFormDialog(
          deckId: widget.deck.id,
          provider: widget.provider,
          onSuccess: () {
            Navigator.of(ctx).pop();
            _load();
          },
        ),
      ),
    );
  }

  void _showEditNoteDialog(BuildContext context, NoteResponse note) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => _NoteFormDialog(
          deckId: widget.deck.id,
          provider: widget.provider,
          existingNote: note,
          onSuccess: () {
            Navigator.of(ctx).pop();
            _load();
          },
        ),
      ),
    );
  }

  void _confirmDeleteNote(BuildContext context, NoteResponse note) {
    final front = (note.fields['Front'] ?? '').toString();
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Note'),
          content:
              Text('Delete "$front"? All cards for this note will be removed.'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
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
      ),
    );
  }

  void _confirmDuplicate(BuildContext context) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Deck'),
          content: Text('Duplicate "${widget.deck.title}"? '
              'This will create a copy with "(copy)" in the title.'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.primary(
              onPressed: () async {
                await widget.provider.duplicateDeck(widget.deck.id);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  _load();
                }
              },
              child: const Text('Duplicate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferOwnerDialog(BuildContext context) {
    final service = UserService(widget.provider.apiClient);
    int? selectedUserId;
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Transfer Ownership'),
            content: SizedBox(
              width: 400,
              child: ShadcnSearchDropdown<SearchResult>(
                hintText: 'Select new owner',
                loader: (query) async => service.searchUsers(query),
                itemBuilder: (ctx, user) =>
                    Text('${user.displayName} (${user.email})'),
                onChanged: (user) {
                  setDialogState(() => selectedUserId = user?.id);
                },
              ),
            ),
            actions: [
              Button.ghost(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              Button.primary(
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
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    final service = UserService(widget.provider.apiClient);
    int? selectedUserId;
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Share Deck'),
            content: SizedBox(
              width: 400,
              child: ShadcnSearchDropdown<SearchResult>(
                hintText: 'Select a collaborator',
                loader: (query) async => service.searchUsers(query),
                itemBuilder: (ctx, user) =>
                    Text('${user.displayName} (${user.email})'),
                onChanged: (user) {
                  setDialogState(() => selectedUserId = user?.id);
                },
              ),
            ),
            actions: [
              Button.ghost(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              Button.primary(
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
                        content: Text(
                            widget.provider.error ?? 'Failed to share deck'),
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
      ),
    );
  }

  void _confirmUnshare(BuildContext context, int userId) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Collaborator'),
          content:
              const Text('Remove this teacher from the deck collaborators?'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
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
      ),
    );
  }

  void _showAddToClassDialog(BuildContext context) {
    final classes = widget.classProvider.classes;
    int? selectedClassId;
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Add to Class'),
            content: SizedBox(
              width: 300,
              child: Select<int>(
                value: selectedClassId,
                placeholder: const Text('Select class'),
                onChanged: (v) => setDialogState(() => selectedClassId = v),
                popup: SelectPopup(
                  items: SelectItemList(children: [
                    for (final c in classes)
                      SelectItemButton(
                        value: c.id,
                        child: Text(c.name),
                      ),
                  ]),
                ),
                itemBuilder: (context, value) {
                  final c = classes.where((c) => c.id == value).firstOrNull;
                  return Text(c?.name ?? '');
                },
              ),
            ),
            actions: [
              Button.ghost(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              Button.primary(
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
      ),
    );
  }

  void _confirmRemoveFromClass(BuildContext context, int classId) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Remove from Class'),
          content: const Text('Remove this deck from the class?'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
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
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: _deckTitle);
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Rename Deck'),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: controller,
              placeholder: const Text('New name'),
              initialValue: _deckTitle,
              autofocus: true,
            ),
          ),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.primary(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                final ok = await widget.provider
                    .renameDeck(widget.deck.id, controller.text.trim());
                if (ok && ctx.mounted) {
                  if (mounted) {
                    setState(() => _deckTitle = controller.text.trim());
                  }
                  Navigator.of(ctx).pop();
                  _load();
                }
              },
              child: const Text('Rename'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDeck(BuildContext context) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Deck'),
          content: Text('Delete "${widget.deck.title}"? '
              'This cannot be undone.'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
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
    final colors = Theme.of(context).colorScheme;
    final isTeacher = widget.canManage;

    return OutlinedContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _isEditingDesc
                    ? TextField(
                        controller: _descController,
                        placeholder: const Text('Deck description...'),
                        initialValue: _descController.text,
                        maxLines: 2,
                      )
                    : widget.deck.description != null &&
                            widget.deck.description!.isNotEmpty
                        ? Text(widget.deck.description!,
                            style: TextStyle(color: colors.mutedForeground))
                        : isTeacher
                            ? Text('Add a description',
                                style: TextStyle(color: colors.mutedForeground))
                            : const SizedBox.shrink(),
              ),
              if (isTeacher)
                _isEditingDesc
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.check, size: 18),
                            onPressed: _isSavingDesc ? null : _saveDescription,
                          ),
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.x, size: 18),
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
                    : IconButton.ghost(
                        icon: const Icon(LucideIcons.pencil, size: 18),
                        onPressed: () => setState(() => _isEditingDesc = true),
                      ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Owner').semiBold(),
              if (widget.canManage) ...[
                const Spacer(),
                Button.ghost(
                  leading: const Icon(LucideIcons.arrowLeftRight, size: 18),
                  onPressed: widget.onTransfer,
                  child: const Text('Transfer'),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              style: const ButtonStyle.outline(),
              leading: Avatar(
                size: 18,
                borderRadius: 9,
                initials: widget.deck.ownerFirstName?.isNotEmpty == true
                    ? widget.deck.ownerFirstName![0].toUpperCase()
                    : widget.deck.createdBy.toString()[0],
              ),
              child: Text(widget.deck.ownerDisplayName),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.collaborators.isNotEmpty || widget.canManage) ...[
            Row(
              children: [
                const Text('Collaborators').semiBold(),
                if (widget.canManage) ...[
                  const Spacer(),
                  Button.ghost(
                    leading: const Icon(LucideIcons.userPlus, size: 18),
                    onPressed: widget.onAddCollaborator,
                    child: const Text('Share'),
                  ),
                ],
              ],
            ),
            if (widget.collaborators.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.collaborators.map((c) {
                    return Chip(
                      style: const ButtonStyle.outline(),
                      leading: Avatar(
                        size: 18,
                        borderRadius: 9,
                        initials: c.firstName.isNotEmpty
                            ? c.firstName[0].toUpperCase()
                            : c.email[0].toUpperCase(),
                      ),
                      trailing: widget.canManage
                          ? ChipButton(
                              onPressed: () =>
                                  widget.onRemoveCollaborator(c.userId),
                              child: const Icon(LucideIcons.x, size: 12),
                            )
                          : null,
                      child: Text(
                          c.displayName.isNotEmpty ? c.displayName : c.email),
                    );
                  }).toList(),
                ),
              )
            else if (widget.canManage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Not shared with anyone yet',
                    style: TextStyle(color: colors.mutedForeground)),
              ),
          ],
          if (widget.canManage || widget.classes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Assigned Classes').semiBold(),
                if (widget.canManage) ...[
                  const Spacer(),
                  Button.ghost(
                    leading: const Icon(LucideIcons.plus, size: 18),
                    onPressed: widget.onAddToClass,
                    child: const Text('Add'),
                  ),
                ],
              ],
            ),
            if (widget.classes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.classes.map((c) {
                    return Chip(
                      style: const ButtonStyle.outline(),
                      leading: const Icon(LucideIcons.users, size: 14),
                      trailing: widget.canManage
                          ? ChipButton(
                              onPressed: () => widget.onRemoveFromClass(c.id),
                              child: const Icon(LucideIcons.x, size: 12),
                            )
                          : null,
                      child: Text(c.name),
                    );
                  }).toList(),
                ),
              )
            else if (widget.canManage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Not assigned to any class',
                    style: TextStyle(color: colors.mutedForeground)),
              ),
          ],
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
  bool _isSubmitting = false;
  bool _loadingTypes = true;
  String? _error;

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
        _selectedType = _noteTypes.cast<NoteType?>().firstWhere(
              (t) => t!.id == widget.existingNote!.noteTypeId,
              orElse: () => _noteTypes.isNotEmpty ? _noteTypes.first : null,
            );
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
    if (_selectedType == null) return;

    // Manual validation
    for (final name in _selectedType!.fieldNames) {
      final text = _fieldControllers[name]?.text.trim() ?? '';
      if (text.isEmpty) {
        setState(() => _error = '$name is required');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

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
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Select<NoteType>(
              value: _selectedType,
              placeholder: const Text('Select note type'),
              onChanged: _isEditing ? null : _onTypeChanged,
              popup: SelectPopup(
                items: SelectItemList(children: [
                  for (final t in _noteTypes)
                    SelectItemButton(
                      value: t,
                      child: Text(t.name),
                    ),
                ]),
              ),
              itemBuilder: (context, value) => Text(value.name),
            ),
            if (_selectedType != null) ...[
              const SizedBox(height: 16),
              for (final name in _selectedType!.fieldNames)
                Padding(
                  padding: EdgeInsets.only(
                      top: _selectedType!.fieldNames.first == name ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 13))
                          .semiBold(),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _fieldControllers[name],
                        placeholder: Text('Enter $name'),
                        initialValue: '',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.destructive,
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
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
