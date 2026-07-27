import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/deck_provider.dart';
import '../models/deck.dart';

class NoteTypesScreen extends StatefulWidget {
  final DeckProvider? provider;

  const NoteTypesScreen({super.key, this.provider});

  @override
  State<NoteTypesScreen> createState() => _NoteTypesScreenState();
}

class _NoteTypesScreenState extends State<NoteTypesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fieldNamesController = TextEditingController();
  final _templateNameController = TextEditingController();
  final _frontPatternController = TextEditingController();
  final _backPatternController = TextEditingController();
  final _sortFieldController = TextEditingController();
  bool _isSubmitting = false;
  final List<_TemplateEntry> _templates = [];

  DeckProvider get _provider => widget.provider ?? context.read<DeckProvider>();

  @override
  void initState() {
    super.initState();
    _provider.loadNoteTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fieldNamesController.dispose();
    _templateNameController.dispose();
    _frontPatternController.dispose();
    _backPatternController.dispose();
    _sortFieldController.dispose();
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
      sortField: _sortFieldController.text.trim().isEmpty
          ? null
          : _sortFieldController.text.trim(),
      templates: _templates
          .map((t) => CreateNoteTemplate(
                name: t.name,
                frontPattern: t.frontPattern,
                backPattern: t.backPattern,
              ))
          .toList(),
    );

    final ok = await _provider.createNoteType(noteType);
    if (mounted) {
      if (ok) {
        _nameController.clear();
        _fieldNamesController.clear();
        _templateNameController.clear();
        _frontPatternController.clear();
        _backPatternController.clear();
        _sortFieldController.clear();
        setState(() {
          _templates.clear();
          _isSubmitting = false;
        });
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_provider.error ?? 'Failed to create note type'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteTypes = _provider.noteTypes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Types'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (noteTypes.isNotEmpty) ...[
            Text('Existing types',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...noteTypes.map((t) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                  'Fields: ${t.fieldNames.join(", ")}${t.sortField.isNotEmpty ? "  •  Sort: ${t.sortField}" : ""}  •  Templates: ${t.templates.map((t) => t.name).join(", ")}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            const Divider(height: 24),
          ],
          Text('Create new type',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortFieldController,
                  decoration: const InputDecoration(
                    labelText: 'Sort field (optional)',
                    hintText: 'e.g. Front — empty uses first field',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Templates',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _templateNameController,
                        decoration: const InputDecoration(
                          labelText: 'Template name',
                          hintText: 'e.g. Forward',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _frontPatternController,
                        decoration: const InputDecoration(
                          labelText: 'Front pattern',
                          hintText: 'e.g. {{Front}}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
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
                  ..._templates.asMap().entries.map((e) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
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
                        ),
                      )),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Create note type'),
                ),
              ],
            ),
          ),
        ],
      ),
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
