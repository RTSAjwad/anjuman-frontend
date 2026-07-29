import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import 'template_detail_screen.dart';

class NoteTypeDetailScreen extends StatefulWidget {
  final DeckProvider provider;
  final NoteType noteType;
  final VoidCallback? onChanged;
  final VoidCallback? onSaved;
  final void Function(int templateIndex)? onTemplateSelected;

  const NoteTypeDetailScreen({
    super.key,
    required this.provider,
    required this.noteType,
    this.onChanged,
    this.onSaved,
    this.onTemplateSelected,
  });

  @override
  State<NoteTypeDetailScreen> createState() => NoteTypeDetailScreenState();
}

class NoteTypeDetailScreenState extends State<NoteTypeDetailScreen> {
  late final TextEditingController _nameController;
  final _fieldNameController = TextEditingController();
  final _templateNameController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  String? _sortField;
  final List<String> _fieldNames = [];
  final List<NoteTemplateEntry> _templates = [];

  // Original values for change detection
  late final String _originalName;
  late final List<String> _originalFieldNames;
  late final String? _originalSortField;
  late final List<NoteTemplateEntry> _originalTemplates;
  bool _initialized = false;

  List<NoteTemplateEntry> get templates => _templates;

  void updateTemplate(int index, NoteTemplateEntry updated) {
    setState(() => _templates[index] = updated);
    _notifyChange();
  }

  bool get hasChanges {
    if (_isSubmitting) return false;
    if (_nameController.text.trim() != _originalName) return true;
    if (_sortField != _originalSortField) return true;
    if (!_listEquals(_fieldNames, _originalFieldNames)) return true;
    if (_templates.length != _originalTemplates.length) return true;
    for (var i = 0; i < _templates.length; i++) {
      if (_templates[i].name != _originalTemplates[i].name ||
          _templates[i].frontPattern != _originalTemplates[i].frontPattern ||
          _templates[i].backPattern != _originalTemplates[i].backPattern) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.noteType;
    _nameController = TextEditingController(text: existing.name);
    _fieldNames.addAll(existing.fieldNames);
    _sortField = existing.sortField.isNotEmpty ? existing.sortField : null;
    _templates.addAll(existing.templates.map((t) => NoteTemplateEntry(
          name: t.name,
          frontPattern: t.frontPattern,
          backPattern: t.backPattern,
        )));

    _originalName = existing.name;
    _originalFieldNames = List.from(existing.fieldNames);
    _originalSortField =
        existing.sortField.isNotEmpty ? existing.sortField : null;
    _originalTemplates = _templates
        .map((t) => NoteTemplateEntry(
              name: t.name,
              frontPattern: t.frontPattern,
              backPattern: t.backPattern,
            ))
        .toList();

    _nameController.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialized = true;
    });
  }

  void _onChanged() {
    setState(() {});
    if (_initialized) {
      widget.onChanged?.call();
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onChanged);
    _nameController.dispose();
    _fieldNameController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  void _addFieldName() {
    final name = _fieldNameController.text.trim();
    if (name.isEmpty || _fieldNames.contains(name)) return;
    setState(() {
      _fieldNames.add(name);
      _fieldNameController.clear();
    });
    _notifyChange();
  }

  void _removeFieldName(int index) {
    setState(() => _fieldNames.removeAt(index));
    _notifyChange();
  }

  void _addTemplate() {
    final name = _templateNameController.text.trim();
    if (name.isEmpty) return;
    final front = '{{$name}}';
    final back = '{{FrontSide}}<hr id=answer>{{Back}}';
    setState(() {
      _templates.add(NoteTemplateEntry(
        name: name,
        frontPattern: front,
        backPattern: back,
      ));
      _templateNameController.clear();
    });
    _notifyChange();
  }

  void _removeTemplate(int index) {
    setState(() => _templates.removeAt(index));
    _notifyChange();
  }

  void _notifyChange() {
    widget.onChanged?.call();
  }

  Future<void> submit() async {
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

    final ok =
        await widget.provider.updateNoteType(widget.noteType.id, noteType);
    if (mounted) {
      if (ok) {
        widget.provider.loadNoteTypes();
        widget.onSaved?.call();
      } else {
        setState(() {
          _isSubmitting = false;
          _error = widget.provider.error ?? 'Failed to update note type';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
          const Text('Field names', style: TextStyle(fontSize: 13)).semiBold(),
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
          const Text('Sort field (optional)', style: TextStyle(fontSize: 13))
              .semiBold(),
          const SizedBox(height: 6),
          Select<String>(
            value: _sortField,
            placeholder: const Text('First field (default)'),
            onChanged: (v) {
              setState(() => _sortField = v);
              _notifyChange();
            },
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
          if (_templates.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _templates.asMap().entries.map((e) {
                final index = e.key;
                final t = e.value;
                return ButtonGroup(
                  children: [
                    ButtonGroupItem(
                      child: OutlineButton(
                        leading: const Icon(LucideIcons.pencil, size: 14),
                        onPressed: () => widget.onTemplateSelected?.call(index),
                        child: Text(t.name),
                      ),
                    ),
                    ButtonGroupItem(
                      child: IconButton.outline(
                        icon: const Icon(LucideIcons.trash2, size: 14),
                        onPressed: () => _removeTemplate(index),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _templateNameController,
                  placeholder: const Text('Template name'),
                  initialValue: '',
                  onSubmitted: (_) => _addTemplate(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.ghost(
                icon: const Icon(LucideIcons.plus, size: 18),
                onPressed: _addTemplate,
              ),
            ],
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
    );
  }
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
