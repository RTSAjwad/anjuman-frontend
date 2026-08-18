import 'package:flutter/material.dart' show Colors;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/riverpod/deck_provider.dart';
import '../models/deck.dart';
import '../config/breakpoints.dart';
import '../widgets/narrow_app_bar.dart';
import '../widgets/responsive_dialog.dart';
import 'note_type_detail_screen.dart';
import 'template_detail_screen.dart';

class NoteTypesScreen extends ConsumerStatefulWidget {
  const NoteTypesScreen({super.key});

  @override
  ConsumerState<NoteTypesScreen> createState() => _NoteTypesScreenState();
}

class _NoteTypesScreenState extends ConsumerState<NoteTypesScreen> {
  bool _saveEnabled = false;
  int? _lastNoteTypeId;
  final Map<int, NoteTypeDraft> _drafts = {};

  NoteTypeDraft? get _currentDraft =>
      _lastNoteTypeId == null ? null : _drafts[_lastNoteTypeId];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(deckProvider.notifier).loadNoteTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final noteTypes = ref.watch(deckProvider).noteTypes;

    final detailIdStr = GoRouterState.of(context).uri.queryParameters['detail'];
    final detailId = detailIdStr != null ? int.tryParse(detailIdStr) : null;
    final templateIndexStr =
        GoRouterState.of(context).uri.queryParameters['template'];
    final templateIndex =
        templateIndexStr != null ? int.tryParse(templateIndexStr) : null;
    final selectedNoteType = noteTypes
        .cast<NoteType?>()
        .firstWhere((t) => t!.id == detailId, orElse: () => null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.of(context).size.width;
        final isCompact = width < Breakpoints.medium;
        final listPaneSize = width >= Breakpoints.large
            ? 360.0
            : (width >= Breakpoints.expanded ? 320.0 : 280.0);

        Widget? fullscreenContent;
        if (selectedNoteType != null) {
          fullscreenContent =
              _buildDetailPane(selectedNoteType, showBack: true);
        }

        // On compact screens, show the template editor when a template is
        // selected (third pane), otherwise show the note type detail.
        if (isCompact) {
          Widget view;
          if (templateIndex != null && selectedNoteType != null) {
            view = _buildTemplateDetailPane(selectedNoteType, showBack: true);
          } else if (fullscreenContent != null) {
            view = fullscreenContent;
          } else {
            view = _buildList(context, colors, noteTypes, isTeacher: false);
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.25, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(templateIndex != null
                  ? 'template_$templateIndex'
                  : (selectedNoteType != null
                      ? 'detail_${selectedNoteType.id}'
                      : 'list')),
              child: view,
            ),
          );
        }

        // Build the note type list widget
        final listWidget = _buildList(context, colors, noteTypes,
            isTeacher: false, selectedId: detailId);

        Widget detailWidget;
        if (selectedNoteType != null) {
          detailWidget = _buildDetailPane(selectedNoteType);
        } else {
          detailWidget = const Center(
            child: Text('Select a note type to view details'),
          );
        }

        return ResizablePanel.horizontal(
          draggerBuilder: (context) {
            return const HorizontalResizableDragger();
          },
          children: [
            ResizablePane(
              initialSize: listPaneSize,
              minSize: 200,
              child: listWidget,
            ),
            ResizablePane.flex(
              child: detailWidget,
            ),
            // Keep the pane count stable. Conditionally adding/removing the
            // third ResizablePane makes shadcn's ResizablePanel reuse elements
            // by position (panes carry no keys), causing crashes when the
            // template detail pane appears/disappears. Instead we always render
            // three panes and swap the third pane's contents.
            ResizablePane.flex(
              child: templateIndex != null && selectedNoteType != null
                  ? KeyedSubtree(
                      key: ValueKey('template_$templateIndex'),
                      child: _buildTemplateDetailPane(selectedNoteType),
                    )
                  : const Center(
                      child: Text('Select a template to view details'),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailPane(NoteType noteType, {bool showBack = false}) {
    if (_lastNoteTypeId != noteType.id) {
      _lastNoteTypeId = noteType.id;
      _saveEnabled = false;
      _drafts.putIfAbsent(noteType.id, () => NoteTypeDraft(noteType));
    }
    final draft = _drafts[noteType.id]!;

    return Scaffold(
      headers: [
        AppBar(
          leading: showBack
              ? [
                  IconButton.outline(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    onPressed: () => context.go('/note-types'),
                  ),
                ]
              : const [],
          title: Text(noteType.name),
          trailing: [
            IconButton.outline(
              icon: const Icon(LucideIcons.save, size: 20),
              onPressed: _saveEnabled ? _submitCurrent : null,
            ),
            IconButton.outline(
              icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.red),
              onPressed: () => _confirmDeleteNoteType(context, noteType),
            ),
          ],
        ),
      ],
      child: KeyedSubtree(
        key: ValueKey(noteType.id),
        child: NoteTypeDetailScreen(
          provider: ref.read(deckProvider.notifier),
          noteType: noteType,
          draft: draft,
          onChanged: () {
            setState(() => _saveEnabled = draft.hasChanges);
          },
          onSaved: () => setState(() => _saveEnabled = false),
          onTemplateSelected: (index) {
            final uri = GoRouterState.of(context).uri;
            context.go(
              uri.replace(
                queryParameters: {
                  ...uri.queryParameters,
                  'template': index.toString(),
                },
              ).toString(),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitCurrent() async {
    final draft = _currentDraft;
    if (draft == null || _lastNoteTypeId == null) return;

    if (draft.name.trim().isEmpty) {
      setState(() => draft.error = 'Name is required');
      return;
    }
    if (draft.fieldNames.isEmpty) {
      setState(() => draft.error = 'Add at least one field name');
      return;
    }
    if (draft.templates.isEmpty) {
      setState(() => draft.error = 'Add at least one template');
      return;
    }

    setState(() {
      draft.isSubmitting = true;
      draft.error = null;
    });

    final notifier = ref.read(deckProvider.notifier);
    final ok = await notifier.updateNoteType(
        _lastNoteTypeId!, draft.toCreateNoteType());
    if (mounted) {
      if (ok) {
        notifier.loadNoteTypes();
        setState(() => _saveEnabled = false);
      } else {
        setState(() {
          draft.isSubmitting = false;
          draft.error = notifier.error ?? 'Failed to update note type';
        });
      }
    }
  }

  Widget _buildTemplateDetailPane(NoteType noteType, {bool showBack = false}) {
    final draft = _drafts[noteType.id];
    final templates = draft?.templates ??
        noteType.templates
            .map((t) => NoteTemplateEntry(
                  name: t.name,
                  frontPattern: t.frontPattern,
                  backPattern: t.backPattern,
                ))
            .toList();
    final templateIndexStr =
        GoRouterState.of(context).uri.queryParameters['template'];
    final templateIndex =
        templateIndexStr != null ? int.tryParse(templateIndexStr) : null;

    if (templateIndex == null || templateIndex >= templates.length) {
      return const Center(
        child: Text('Select a template to view details'),
      );
    }

    final template = templates[templateIndex];

    return Scaffold(
      headers: [
        AppBar(
          leading: showBack
              ? [
                  IconButton.outline(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    onPressed: () {
                      final uri = GoRouterState.of(context).uri;
                      final params =
                          Map<String, String>.from(uri.queryParameters);
                      params.remove('template');
                      context
                          .go(uri.replace(queryParameters: params).toString());
                    },
                  ),
                ]
              : const [],
          title: Text(template.name),
          trailing: [
            if (!showBack)
              IconButton.outline(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () {
                  final uri = GoRouterState.of(context).uri;
                  final params = Map<String, String>.from(uri.queryParameters);
                  params.remove('template');
                  context.go(uri.replace(queryParameters: params).toString());
                },
              ),
          ],
        ),
      ],
      child: KeyedSubtree(
        key: ValueKey('template_$templateIndex'),
        child: TemplateDetailScreen(
          template: template,
          onChanged: (updated) {
            draft?.updateTemplate(templateIndex, updated);
            setState(() => _saveEnabled = draft?.hasChanges ?? false);
          },
        ),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, ColorScheme colors, List<NoteType> noteTypes,
      {bool isTeacher = false, int? selectedId}) {
    if (noteTypes.isEmpty) {
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
                onPressed: () =>
                    ref.read(deckProvider.notifier).loadNoteTypes(),
              ),
            ],
          ),
        ],
        child: Center(
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
                style: TextStyle(color: colors.mutedForeground, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

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
              onPressed: () => ref.read(deckProvider.notifier).loadNoteTypes(),
            ),
          ],
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: OutlinedContainer(
                child: Table(
                  rows: [
                    for (final t in noteTypes)
                      TableRow(cells: [
                        TableCell(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                context.go('/note-types?detail=${t.id}'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              color: selectedId == t.id
                                  ? colors.primary.scaleAlpha(0.05)
                                  : null,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(t.name).semiBold(),
                                        const SizedBox(width: 8),
                                        OutlineBadge(
                                          child: Text('${t.noteCount} notes'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selectedId == t.id)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(LucideIcons.chevronRight),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showResponsiveDialog(
      context,
      builder: (ctx, _) => _CreateNoteTypeDialog(
        provider: ref.read(deckProvider.notifier),
        onSuccess: () {
          safeCloseOverlay(ctx);
          setState(() {});
        },
      ),
    );
  }

  void _confirmDeleteNoteType(BuildContext context, NoteType noteType) {
    showResponsiveDialog(
      context,
      builder: (ctx, _) => AlertDialog(
        title: const Text('Delete Note Type'),
        content: Text(
            'Delete "${noteType.name}"? This will also delete all notes using this type.'),
        actions: [
          Button.ghost(
            onPressed: () => closeOverlay(ctx),
            child: const Text('Cancel'),
          ),
          Button.destructive(
            onPressed: () async {
              final ok = await ref
                  .read(deckProvider.notifier)
                  .deleteNoteType(noteType.id);
              if (ctx.mounted) {
                safeCloseOverlay(ctx);
                if (ok) {
                  setState(() {});
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

class _CreateNoteTypeDialog extends StatefulWidget {
  final DeckNotifier provider;
  final VoidCallback onSuccess;

  const _CreateNoteTypeDialog({
    required this.provider,
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

  @override
  void initState() {
    super.initState();
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

    final ok = await widget.provider.createNoteType(noteType);
    if (mounted) {
      if (ok) {
        widget.onSuccess();
      } else {
        setState(() {
          _isSubmitting = false;
          _error = widget.provider.error ?? 'Failed to create note type';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Create Note Type'),
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
