import 'package:flutter/material.dart'
    show ScaffoldMessenger, SnackBar, SnackBarBehavior;
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import 'class_detail_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().loadClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTeacher = auth.role == 'teacher' || auth.role == 'admin';
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Classes'),
          trailing: [
            if (isTeacher)
              IconButton.ghost(
                icon: const Icon(LucideIcons.plus, size: 20),
                onPressed: () => _showCreateDialog(context),
              ),
            IconButton.ghost(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: () => context.read<ClassProvider>().loadClasses(),
            ),
          ],
        ),
      ],
      child: Consumer<ClassProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.classes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.circleAlert,
                      size: 48, color: colors.destructive),
                  const SizedBox(height: 16),
                  const Text('Failed to load classes'),
                  const SizedBox(height: 8),
                  Button.secondary(
                    onPressed: () => provider.loadClasses(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.users,
                      size: 64, color: colors.mutedForeground),
                  const SizedBox(height: 16),
                  Text(
                    isTeacher ? 'No classes yet' : 'No classes',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTeacher
                        ? 'Create your first class to get started'
                        : 'You are not enrolled in any classes yet',
                    style:
                        TextStyle(color: colors.mutedForeground, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: OutlinedContainer(
                    child: Table(
                      rows: [
                        for (final c in provider.classes)
                          TableRow(cells: [
                            TableCell(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ClassDetailScreen(
                                        classResponse: c,
                                        provider: provider,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Text(c.name).semiBold(),
                                                if (c.archived) ...[
                                                  const SizedBox(width: 8),
                                                  OutlineBadge(
                                                    child:
                                                        const Text('Archived'),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (c.description != null &&
                                                c.description!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                c.description!,
                                                style: TextStyle(
                                                    color:
                                                        colors.mutedForeground),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(LucideIcons.chevronRight,
                                          size: 20,
                                          color: colors.mutedForeground),
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
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final provider = context.read<ClassProvider>();
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => _CreateClassDialog(provider: provider),
      ),
    );
  }
}

class _CreateClassDialog extends StatefulWidget {
  final ClassProvider provider;

  const _CreateClassDialog({required this.provider});

  @override
  State<_CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends State<_CreateClassDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result = await widget.provider.createClass(
      name,
      _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (mounted) {
      if (result != null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.provider.error ?? 'Failed to create class'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Class'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Class name', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              placeholder: const Text('e.g. Biology 101'),
              initialValue: '',
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('Description (optional)', style: TextStyle(fontSize: 13))
                .semiBold(),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              placeholder: const Text('Add a description'),
              initialValue: '',
              maxLines: 2,
            ),
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
              : const Text('Create'),
        ),
      ],
    );
  }
}
