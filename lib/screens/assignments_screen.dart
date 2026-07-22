import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assignment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/study_provider.dart';
import '../screens/study_screen.dart';
import '../models/assignment.dart';
import '../models/class.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  List<_AssignmentWithClass> _assignments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final classProvider = context.read<ClassProvider>();
    final assignmentProvider = context.read<AssignmentProvider>();

    await classProvider.loadClasses();
    final classes = classProvider.classes;

    if (classProvider.error != null || classes.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = classProvider.error ?? 'No classes found';
      });
      return;
    }

    final all = <_AssignmentWithClass>[];
    for (final c in classes) {
      try {
        final list = await assignmentProvider.listAssignments(c.id);
        for (final a in list) {
          all.add(_AssignmentWithClass(a, c));
        }
      } on Exception catch (e) {
        print('Failed to load assignments for class ${c.id}: $e');
      }
    }

    setState(() {
      _assignments = all;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTeacher = context.watch<AuthProvider>().role != 'student';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _assignments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text('No assignments yet',
                              style: theme.textTheme.titleMedium),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _assignments.length,
                        itemBuilder: (context, index) {
                          final item = _assignments[index];
                          final a = item.assignment;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(a.title,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                      ),
                                      if (a.published)
                                        _Badge(
                                            label: 'Published',
                                            color: theme
                                                .colorScheme.primaryContainer,
                                            textColor: theme.colorScheme
                                                .onPrimaryContainer),
                                      if (a.archived) ...[
                                        const SizedBox(width: 4),
                                        _Badge(
                                            label: 'Archived',
                                            color: theme.colorScheme
                                                .surfaceContainerHighest,
                                            textColor: theme
                                                .colorScheme.onSurfaceVariant),
                                      ],
                                      if (isTeacher)
                                        PopupMenuButton<String>(
                                          onSelected: (action) =>
                                              switch (action) {
                                            'publish' =>
                                              _toggle(a.id, 'publish'),
                                            'archive' =>
                                              _toggle(a.id, 'archive'),
                                            'delete' => _confirmDelete(a),
                                            _ => null,
                                          },
                                          itemBuilder: (ctx) => [
                                            PopupMenuItem(
                                              value: 'publish',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    a.published
                                                        ? Icons.visibility_off
                                                        : Icons.visibility,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(a.published
                                                      ? 'Unpublish'
                                                      : 'Publish'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'archive',
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.archive,
                                                      size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(a.archived
                                                      ? 'Unarchive'
                                                      : 'Archive'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline,
                                                      size: 20,
                                                      color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.group,
                                          size: 14,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(item.className,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          )),
                                      if (a.dueAt != null) ...[
                                        const SizedBox(width: 16),
                                        Icon(Icons.calendar_today,
                                            size: 14,
                                            color: theme
                                                .colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTimestamp(a.dueAt!),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.group,
                                          size: 14,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(item.className,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          )),
                                      if (a.dueAt != null) ...[
                                        const SizedBox(width: 16),
                                        Icon(Icons.calendar_today,
                                            size: 14,
                                            color: theme
                                                .colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTimestamp(a.dueAt!),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (!isTeacher &&
                                          a.published &&
                                          !a.archived)
                                        if (!isTeacher &&
                                            a.published &&
                                            !a.archived)
                                          FilledButton.tonalIcon(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => StudyScreen(
                                                    deckId: a.id,
                                                    provider: context
                                                        .read<StudyProvider>(),
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.psychology,
                                                size: 18),
                                            label: const Text('Study'),
                                          ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              heroTag: 'create_assignment',
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Assignment'),
            )
          : null,
    );
  }

  void _showCreateDialog(BuildContext context) {
    final deckProvider = context.read<DeckProvider>();
    final assignmentProvider = context.read<AssignmentProvider>();
    final classes = context.read<ClassProvider>().classes;
    deckProvider.loadDecks();
    showDialog(
      context: context,
      builder: (ctx) => _CreateAssignmentDialog(
        deckProvider: deckProvider,
        assignmentProvider: assignmentProvider,
        classes: classes,
        onCreated: _load,
      ),
    );
  }

  void _confirmDelete(AssignmentResponse a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Delete "${a.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final ok = await context
                  .read<AssignmentProvider>()
                  .deleteAssignment(a.id);
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

  Future<void> _toggle(int id, String action) async {
    final provider = context.read<AssignmentProvider>();
    if (action == 'publish') {
      await provider.publishAssignment(id);
    } else {
      await provider.archiveAssignment(id);
    }
    _load();
  }

  String _formatTimestamp(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _AssignmentWithClass {
  final AssignmentResponse assignment;
  final String className;
  final int classId;

  _AssignmentWithClass(this.assignment, ClassResponse c)
      : className = c.name,
        classId = c.id;
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              )),
    );
  }
}

class _CreateAssignmentDialog extends StatefulWidget {
  final DeckProvider deckProvider;
  final AssignmentProvider assignmentProvider;
  final List<ClassResponse> classes;
  final VoidCallback onCreated;

  const _CreateAssignmentDialog({
    required this.deckProvider,
    required this.assignmentProvider,
    required this.classes,
    required this.onCreated,
  });

  @override
  State<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<_CreateAssignmentDialog> {
  int? _selectedClassId;
  int? _selectedDeckId;
  final _titleCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedClassId == null ||
        _selectedDeckId == null ||
        _titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await widget.assignmentProvider.createAssignment(
      _selectedClassId!,
      CreateAssignment(
        deckId: _selectedDeckId!,
        title: _titleCtrl.text.trim(),
      ),
    );
    if (mounted) {
      if (ok) {
        Navigator.of(context).pop();
        widget.onCreated();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.assignmentProvider.error ??
                'Failed to create assignment'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.deckProvider,
      builder: (context, _) {
        final decks = widget.deckProvider.decks;
        return AlertDialog(
          title: const Text('Create Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedClassId,
                    hint: const Text('Select class'),
                    isExpanded: true,
                    items: widget.classes
                        .map((c) => DropdownMenuItem<int>(
                            value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedClassId = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Deck',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedDeckId,
                    hint: const Text('Select deck'),
                    isExpanded: true,
                    items: decks
                        .map((d) => DropdownMenuItem<int>(
                            value: d.id, child: Text(d.title)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDeckId = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                  : const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
