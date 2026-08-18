import 'package:flutter/material.dart'
    show ScaffoldMessenger, SnackBar, SnackBarBehavior;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/riverpod/auth_provider.dart';
import '../providers/riverpod/class_provider.dart';
import 'class_detail_screen.dart';
import '../models/class.dart';
import '../widgets/narrow_app_bar.dart';
import '../widgets/responsive_dialog.dart';
import '../config/breakpoints.dart';

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(classProvider.notifier).loadClasses();
    });
  }

  int? _selectedDetailId() {
    final detail = GoRouterState.of(context).uri.queryParameters['detail'];
    return detail != null ? int.tryParse(detail) : null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isTeacher = auth.role == 'teacher' || auth.role == 'admin';
    final colors = Theme.of(context).colorScheme;
    final provider = ref.watch(classProvider);

    return Scaffold(
      child: Builder(
        builder: (context) {
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
                    onPressed: () =>
                        ref.read(classProvider.notifier).loadClasses(),
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = MediaQuery.of(context).size.width;
              final isCompact = width < Breakpoints.medium;
              final listPaneSize = width >= Breakpoints.large
                  ? 360.0
                  : (width >= Breakpoints.expanded ? 320.0 : 280.0);
              final detailId = _selectedDetailId();
              final selectedClass = detailId != null
                  ? provider.classes
                      .cast<ClassResponse?>()
                      .firstWhere((c) => c?.id == detailId, orElse: () => null)
                  : null;

              final classNotifier = ref.read(classProvider.notifier);

              Widget? embeddedContent;
              if (selectedClass != null) {
                embeddedContent = KeyedSubtree(
                  key: ValueKey(selectedClass.id),
                  child: ClassDetailScreen(
                    classResponse: selectedClass,
                    provider: classNotifier,
                    onClose: () => context.go('/classes'),
                  ),
                );
              }

              // Compact: show selected class with back button
              if (isCompact && selectedClass != null) {
                return ClassDetailScreen(
                  classResponse: selectedClass,
                  provider: classNotifier,
                  onClose: () => context.go('/classes'),
                  showBack: true,
                );
              }

              // Compact: show class list only
              if (isCompact) {
                return Column(
                  children: [
                    NarrowAppBar(
                      title: const Text('Classes'),
                      trailing: [
                        if (isTeacher)
                          IconButton.outline(
                            icon: const Icon(LucideIcons.plus, size: 20),
                            onPressed: () => _showCreateDialog(context),
                          ),
                        IconButton.outline(
                          icon: const Icon(LucideIcons.refreshCw, size: 20),
                          onPressed: () =>
                              ref.read(classProvider.notifier).loadClasses(),
                        ),
                      ],
                    ),
                    Expanded(
                        child: _buildClassList(isTeacher, colors, provider)),
                  ],
                );
              }

              // Medium or Expanded: resizable dual pane
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
                          title: const Text('Classes'),
                          trailing: [
                            if (isTeacher)
                              IconButton.outline(
                                icon: const Icon(LucideIcons.plus, size: 20),
                                onPressed: () => _showCreateDialog(context),
                              ),
                            IconButton.outline(
                              icon: const Icon(LucideIcons.refreshCw, size: 20),
                              onPressed: () => ref
                                  .read(classProvider.notifier)
                                  .loadClasses(),
                            ),
                          ],
                        ),
                        Expanded(
                            child:
                                _buildClassList(isTeacher, colors, provider)),
                      ],
                    ),
                  ),
                  ResizablePane.flex(
                    child: embeddedContent ??
                        const Center(
                          child: Text('Select a class to view details'),
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

  Widget _buildClassList(
      bool isTeacher, ColorScheme colors, ClassState provider) {
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
                            context.go('/classes?detail=${c.id}');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            color: _selectedDetailId() == c.id
                                ? colors.primary.scaleAlpha(0.05)
                                : null,
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
                                            const OutlineBadge(
                                              child: Text('Archived'),
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
                                              color: colors.mutedForeground),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_selectedDetailId() == c.id)
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
    );
  }

  void _showCreateDialog(BuildContext context) {
    final provider = ref.read(classProvider.notifier);
    showResponsiveDialog(
      context,
      builder: (ctx, _) => _CreateClassDialog(provider: provider),
    );
  }
}

class _CreateClassDialog extends StatefulWidget {
  final ClassNotifier provider;

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
        safeCloseOverlay(context);
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
