import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import 'template_detail_screen.dart';

/// The editable, in-progress state for a note type being viewed/edited.
///
/// This lives in [NoteTypesScreen] (the parent) so it survives compact-screen
/// pane swaps (list → detail → template), where individual panes are mounted
/// and unmounted. Both [NoteTypeDetailScreen] and the template editor read and
/// mutate this single draft.
class NoteTypeDraft {
  String name;
  final List<String> fieldNames;
  String? sortField;
  final List<NoteTemplateEntry> templates;
  bool isSubmitting = false;
  String? error;

  // Original values used to detect unsaved changes.
  final String _originalName;
  final List<String> _originalFieldNames;
  final String? _originalSortField;
  final List<NoteTemplateEntry> _originalTemplates;

  NoteTypeDraft(NoteType source)
      : name = source.name,
        fieldNames = List.from(source.fieldNames),
        sortField = source.sortField.isNotEmpty ? source.sortField : null,
        templates = source.templates
            .map((t) => NoteTemplateEntry(
                  name: t.name,
                  frontPattern: t.frontPattern,
                  backPattern: t.backPattern,
                ))
            .toList(),
        _originalName = source.name,
        _originalFieldNames = List.from(source.fieldNames),
        _originalSortField =
            source.sortField.isNotEmpty ? source.sortField : null,
        _originalTemplates = <NoteTemplateEntry>[] {
    // Snapshot the initial templates so `hasChanges` can detect edits.
    _originalTemplates.addAll(templates);
  }

  bool get hasChanges {
    if (isSubmitting) return false;
    if (name.trim() != _originalName) return true;
    if (sortField != _originalSortField) return true;
    if (!_listEquals(fieldNames, _originalFieldNames)) return true;
    if (templates.length != _originalTemplates.length) return true;
    for (var i = 0; i < templates.length; i++) {
      if (templates[i].name != _originalTemplates[i].name ||
          templates[i].frontPattern != _originalTemplates[i].frontPattern ||
          templates[i].backPattern != _originalTemplates[i].backPattern) {
        return true;
      }
    }
    return false;
  }

  void addFieldName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || fieldNames.contains(trimmed)) return;
    fieldNames.add(trimmed);
  }

  void removeFieldName(int index) {
    fieldNames.removeAt(index);
  }

  void addTemplate(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    templates.add(NoteTemplateEntry(
      name: trimmed,
      frontPattern: '{{$trimmed}}',
      backPattern: '{{FrontSide}}<hr id=answer>{{Back}}',
    ));
  }

  void removeTemplate(int index) {
    templates.removeAt(index);
  }

  void updateTemplate(int index, NoteTemplateEntry updated) {
    templates[index] = updated;
  }

  CreateNoteType toCreateNoteType() {
    return CreateNoteType(
      name: name.trim(),
      fieldNames: List<String>.from(fieldNames),
      sortField: sortField,
      templates: templates
          .map((t) => CreateNoteTemplate(
                name: t.name,
                frontPattern: t.frontPattern,
                backPattern: t.backPattern,
              ))
          .toList(),
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A read-only view over a [NoteTypeDraft] mutated through callbacks.
///
/// All editable state lives in the [NoteTypeDraft] passed in by the parent.
/// This widget renders the form and reports mutations upward.
class NoteTypeDetailScreen extends StatefulWidget {
  final DeckProvider provider;
  final NoteType noteType;
  final NoteTypeDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onSaved;
  final void Function(int templateIndex)? onTemplateSelected;

  const NoteTypeDetailScreen({
    super.key,
    required this.provider,
    required this.noteType,
    required this.draft,
    required this.onChanged,
    this.onSaved,
    this.onTemplateSelected,
  });

  @override
  State<NoteTypeDetailScreen> createState() => _NoteTypeDetailScreenState();
}

class _NoteTypeDetailScreenState extends State<NoteTypeDetailScreen> {
  late final TextEditingController _nameController;
  final _fieldNameController = TextEditingController();
  final _templateNameController = TextEditingController();
  bool _initialized = false;

  NoteTypeDraft get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _draft.name);
    _nameController.addListener(_onNameChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _fieldNameController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    _draft.name = _nameController.text;
    if (_initialized) widget.onChanged();
  }

  void _addFieldName() {
    final before = _draft.fieldNames.length;
    _draft.addFieldName(_fieldNameController.text);
    if (_draft.fieldNames.length != before) _fieldNameController.clear();
    widget.onChanged();
  }

  void _removeFieldName(int index) {
    _draft.removeFieldName(index);
    widget.onChanged();
  }

  void _addTemplate() {
    _draft.addTemplate(_templateNameController.text);
    _templateNameController.clear();
    widget.onChanged();
  }

  void _removeTemplate(int index) {
    _draft.removeTemplate(index);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final draft = _draft;

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
          if (draft.fieldNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: draft.fieldNames.asMap().entries.map((e) {
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
            value: draft.sortField,
            placeholder: const Text('First field (default)'),
            onChanged: (v) {
              setState(() => draft.sortField = v);
              widget.onChanged();
            },
            canUnselect: true,
            popup: SelectPopup(
              items: SelectItemList(children: [
                for (final name in draft.fieldNames)
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
          if (draft.templates.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: draft.templates.asMap().entries.map((e) {
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
                        icon: const Icon(LucideIcons.trash2,
                            size: 14, color: Colors.red),
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
          if (draft.error != null) ...[
            const SizedBox(height: 8),
            Text(
              draft.error!,
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
