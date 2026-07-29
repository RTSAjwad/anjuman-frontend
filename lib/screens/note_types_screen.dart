import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/deck_provider.dart';
import '../models/deck.dart';
import '../widgets/narrow_app_bar.dart';

class NoteTypesScreen extends StatefulWidget {
  final DeckProvider? provider;

  const NoteTypesScreen({super.key, this.provider});

  @override
  State<NoteTypesScreen> createState() => _NoteTypesScreenState();
}

class _NoteTypesScreenState extends State<NoteTypesScreen> {
  DeckProvider get _provider => widget.provider ?? context.read<DeckProvider>();
  late final DeckProvider _cachedProvider;

  @override
  void initState() {
    super.initState();
    _cachedProvider = _provider;
    _cachedProvider.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cachedProvider.loadNoteTypes();
    });
  }

  @override
  void dispose() {
    _cachedProvider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final noteTypes = _provider.noteTypes;

    return Scaffold(
      headers: [
        NarrowAppBar(
          title: const Text('Note Types'),
          trailing: [
            IconButton.outline(
              icon: const Icon(LucideIcons.plus, size: 20),
              onPressed: () => _showCreateDialog(context),
            ),
            IconButton.outline(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: () => _provider.loadNoteTypes(),
            ),
          ],
        ),
      ],
      child: noteTypes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.fileText,
                      size: 64, color: colors.mutedForeground),
                  const SizedBox(height: 16),
                  const Text('No note types yet'),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first note type to get started',
                    style:
                        TextStyle(color: colors.mutedForeground, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedContainer(
                  child: Column(
                    children: noteTypes
                        .map((t) => Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: colors.border, width: 0.5),
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.fileText,
                                      size: 20, color: colors.mutedForeground),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(t.name).semiBold(),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fields: ${t.fieldNames.join(", ")}${t.sortField.isNotEmpty ? "  •  Sort: ${t.sortField}" : ""}  •  Templates: ${t.templates.map((t) => t.name).join(", ")}  •  Notes: ${t.noteCount}',
                                          style: TextStyle(
                                              color: colors.mutedForeground,
                                              fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tooltip(
                                    tooltip: (context) =>
                                        const Text('Edit note type'),
                                    child: IconButton.outline(
                                      icon: const Icon(LucideIcons.pencil,
                                          size: 18),
                                      onPressed: () =>
                                          _showEditDialog(context, t),
                                    ),
                                  ),
                                  Tooltip(
                                    tooltip: (context) => Text(t.hasNotes
                                        ? 'Cannot delete: ${t.noteCount} note${t.noteCount == 1 ? '' : 's'} use this type'
                                        : 'Delete note type'),
                                    child: IconButton.outline(
                                      icon: Icon(LucideIcons.trash2,
                                          size: 18,
                                          color: t.hasNotes
                                              ? colors.mutedForeground
                                              : Colors.red),
                                      onPressed: t.hasNotes
                                          ? null
                                          : () => _confirmDeleteNoteType(
                                              context, t),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => _CreateNoteTypeDialog(
          provider: _provider,
          onSuccess: () {
            Navigator.of(ctx).pop();
            setState(() {});
          },
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, NoteType noteType) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => _CreateNoteTypeDialog(
          provider: _provider,
          existingNoteType: noteType,
          onSuccess: () {
            Navigator.of(ctx).pop();
            setState(() {});
          },
        ),
      ),
    );
  }

  void _confirmDeleteNoteType(BuildContext context, NoteType noteType) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Note Type'),
          content: Text(
              'Delete "${noteType.name}"? This will also delete all notes using this type.'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
              onPressed: () async {
                final ok = await _provider.deleteNoteType(noteType.id);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  if (ok) {
                    setState(() {});
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

class _CreateNoteTypeDialog extends StatefulWidget {
  final DeckProvider provider;
  final NoteType? existingNoteType;
  final VoidCallback onSuccess;

  const _CreateNoteTypeDialog({
    required this.provider,
    this.existingNoteType,
    required this.onSuccess,
  });

  @override
  State<_CreateNoteTypeDialog> createState() => _CreateNoteTypeDialogState();
}

class _CreateNoteTypeDialogState extends State<_CreateNoteTypeDialog> {
  final _nameController = TextEditingController();
  final _fieldNameController = TextEditingController();
  final _templateNameController = TextEditingController();
  final _frontPatternController = TextEditingController();
  final _backPatternController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  String? _sortField;
  final List<String> _fieldNames = [];
  final List<_TemplateEntry> _templates = [];

  bool get _isEditing => widget.existingNoteType != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingNoteType;
    if (existing != null) {
      _nameController.text = existing.name;
      _fieldNames.addAll(existing.fieldNames);
      _sortField = existing.sortField.isNotEmpty ? existing.sortField : null;
      _templates.addAll(existing.templates.map((t) => _TemplateEntry(
            name: t.name,
            frontPattern: t.frontPattern,
            backPattern: t.backPattern,
          )));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fieldNameController.dispose();
    _templateNameController.dispose();
    _frontPatternController.dispose();
    _backPatternController.dispose();
    super.dispose();
  }

  void _addFieldName() {
    final name = _fieldNameController.text.trim();
    if (name.isEmpty || _fieldNames.contains(name)) return;
    setState(() {
      _fieldNames.add(name);
      _fieldNameController.clear();
    });
  }

  void _removeFieldName(int index) {
    setState(() => _fieldNames.removeAt(index));
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (_fieldNames.isEmpty) {
      setState(() => _error = 'Add at least one field name');
      return;
    }
    if (_templates.isEmpty) {
      setState(() => _error = 'Add at least one template');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final noteType = CreateNoteType(
      name: name,
      fieldNames: List<String>.from(_fieldNames),
      sortField: _sortField,
      templates: _templates
          .map((t) => CreateNoteTemplate(
                name: t.name,
                frontPattern: t.frontPattern,
                backPattern: t.backPattern,
              ))
          .toList(),
    );

    final ok = _isEditing
        ? await widget.provider
            .updateNoteType(widget.existingNoteType!.id, noteType)
        : await widget.provider.createNoteType(noteType);
    if (mounted) {
      if (ok) {
        widget.onSuccess();
      } else {
        setState(() {
          _isSubmitting = false;
          _error = widget.provider.error ??
              'Failed to ${_isEditing ? 'update' : 'create'} note type';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Note Type' : 'Create Note Type'),
      content: SizedBox(
        width: 500,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Name', style: TextStyle(fontSize: 13)).semiBold(),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  placeholder: const Text('e.g. Basic, Cloze'),
                  initialValue: _nameController.text,
                ),
                const SizedBox(height: 12),
                const Text('Field names', style: TextStyle(fontSize: 13))
                    .semiBold(),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fieldNameController,
                        placeholder: const Text('e.g. Front'),
                        initialValue: '',
                        onSubmitted: (_) => _addFieldName(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.plus, size: 18),
                      onPressed: _addFieldName,
                    ),
                  ],
                ),
                if (_fieldNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _fieldNames.asMap().entries.map((e) {
                      return Chip(
                        style: const ButtonStyle.outline(),
                        trailing: ChipButton(
                          onPressed: () => _removeFieldName(e.key),
                          child: const Icon(LucideIcons.x, size: 12),
                        ),
                        child: Text(e.value),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                const Text('Sort field (optional)',
                        style: TextStyle(fontSize: 13))
                    .semiBold(),
                const SizedBox(height: 6),
                Select<String>(
                  value: _sortField,
                  placeholder: const Text('First field (default)'),
                  onChanged: (v) => setState(() => _sortField = v),
                  canUnselect: true,
                  popup: SelectPopup(
                    items: SelectItemList(children: [
                      for (final name in _fieldNames)
                        SelectItemButton(
                          value: name,
                          child: Text(name),
                        ),
                    ]),
                  ),
                  itemBuilder: (context, value) => Text(value),
                ),
                const SizedBox(height: 16),
                const Text('Templates').semiBold(),
                const SizedBox(height: 8),
                const Text('Template name', style: TextStyle(fontSize: 13))
                    .semiBold(),
                const SizedBox(height: 6),
                TextField(
                  controller: _templateNameController,
                  placeholder: const Text('e.g. Forward'),
                  initialValue: '',
                ),
                const SizedBox(height: 12),
                const Text('Front pattern', style: TextStyle(fontSize: 13))
                    .semiBold(),
                const SizedBox(height: 6),
                TextArea(
                  controller: _frontPatternController,
                  placeholder: const Text('e.g. {{Front}}'),
                  initialValue: '',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                const Text('Back pattern', style: TextStyle(fontSize: 13))
                    .semiBold(),
                const SizedBox(height: 6),
                TextArea(
                  controller: _backPatternController,
                  placeholder: const Text('e.g. {{Back}}'),
                  initialValue: '',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Button.secondary(
                  leading: const Icon(LucideIcons.plus, size: 16),
                  onPressed: _addTemplate,
                  child: const Text('Add template'),
                ),
                if (_templates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._templates.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: OutlinedContainer(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${e.value.name}: ${e.value.frontPattern} / ${e.value.backPattern}',
                                  style: TextStyle(
                                      color: colors.mutedForeground,
                                      fontSize: 13),
                                ),
                              ),
                              IconButton.ghost(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () => _removeTemplate(e.key),
                              ),
                            ],
                          ),
                        ),
                      )),
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
