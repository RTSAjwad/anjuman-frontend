import 'package:flutter/material.dart'
    show Colors, ScaffoldMessenger, SnackBar, SnackBarBehavior;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../models/class.dart';
import '../models/search_result.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';
import '../widgets/responsive_dialog.dart';
import '../widgets/shadcn_search_dropdown.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassResponse classResponse;
  final ClassProvider provider;
  final VoidCallback? onClose;
  final bool showBack;

  const ClassDetailScreen({
    super.key,
    required this.classResponse,
    required this.provider,
    this.onClose,
    this.showBack = false,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  late Future<RosterResponse?> _rosterFuture;
  final _verticalScrollController = ScrollController();
  final _tableScrollController = ScrollController();

  late ClassProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _rosterFuture = _provider.loadRoster(widget.classResponse.id);
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTeacher = auth.role == 'teacher' || auth.role == 'admin';
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<RosterResponse?>(
      future: _rosterFuture,
      builder: (context, snapshot) {
        final roster = snapshot.data;
        final members = roster?.members ?? const <MemberResponse>[];
        final teacherCount = members.where((m) => m.role == 'teacher').length;
        final studentCount = members.where((m) => m.role == 'student').length;

        return Scaffold(
          child: Column(
            children: [
              AppBar(
                leading: [
                  if (widget.showBack)
                    IconButton.outline(
                      icon: const Icon(LucideIcons.arrowLeft, size: 20),
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                ],
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.classResponse.name),
                    if (roster != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlineBadge(
                              leading: const Icon(LucideIcons.graduationCap,
                                  size: 14),
                              child: Text(
                                  '$teacherCount teacher${teacherCount == 1 ? '' : 's'}'),
                            ),
                            const SizedBox(width: 8),
                            OutlineBadge(
                              leading: const Icon(LucideIcons.users, size: 14),
                              child: Text(
                                  '$studentCount student${studentCount == 1 ? '' : 's'}'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                trailing: [
                  if (isTeacher)
                    IconButton.outline(
                      icon: const Icon(LucideIcons.userPlus, size: 20),
                      onPressed: () => _showAddMemberDialog(context),
                    ),
                  if (isTeacher)
                    IconButton.outline(
                      icon: const Icon(LucideIcons.trash2,
                          size: 20, color: Colors.red),
                      onPressed: () => _confirmDelete(context),
                    ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _buildBody(snapshot, colors, isTeacher, members),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<RosterResponse?> snapshot,
    ColorScheme colors,
    bool isTeacher,
    List<MemberResponse> members,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, size: 48, color: colors.destructive),
            const SizedBox(height: 16),
            const Text('Failed to load roster'),
            const SizedBox(height: 8),
            Button.secondary(
              onPressed: () {
                setState(() {
                  _rosterFuture = _provider.loadRoster(widget.classResponse.id);
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (members.isEmpty) {
      return const Center(child: Text('No members'));
    }

    final cellTheme = TableCellTheme(
      border: WidgetStatePropertyAll(
        Border.all(
          color: colors.border,
          strokeAlign: BorderSide.strokeAlignCenter,
        ),
      ),
    );

    final rows = <TableRow>[
      TableHeader(cells: [
        TableCell(
          theme: cellTheme,
          child: Container(
            padding: const EdgeInsets.all(8),
            child:
                const Text('', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        _headerCell('First Name', cellTheme),
        _headerCell('Last Name', cellTheme),
        _headerCell('Email', cellTheme),
        _headerCell('Role', cellTheme),
        _headerCell('Joined', cellTheme),
        if (isTeacher)
          TableCell(theme: cellTheme, child: const SizedBox(width: 48)),
      ]),
      for (final member in members)
        TableRow(cells: [
          TableCell(
            theme: cellTheme,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Avatar(
                size: 28,
                borderRadius: 14,
                initials: member.firstName.isNotEmpty
                    ? member.firstName[0].toUpperCase()
                    : member.email[0].toUpperCase(),
              ),
            ),
          ),
          TableCell(
            theme: cellTheme,
            child: Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.centerLeft,
              child: Text(member.firstName, overflow: TextOverflow.ellipsis),
            ),
          ),
          TableCell(
            theme: cellTheme,
            child: Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.centerLeft,
              child: Text(member.lastName, overflow: TextOverflow.ellipsis),
            ),
          ),
          TableCell(
            theme: cellTheme,
            child: Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.centerLeft,
              child: Text(member.email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.mutedForeground)),
            ),
          ),
          TableCell(
            theme: cellTheme,
            child: Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.centerLeft,
              child: _RoleBadge(role: member.role),
            ),
          ),
          TableCell(
            theme: cellTheme,
            child: Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.centerLeft,
              child: Text(
                _formatJoined(member.joinedAt),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.mutedForeground),
              ),
            ),
          ),
          if (isTeacher)
            TableCell(
              theme: cellTheme,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton.ghost(
                  icon: const Icon(LucideIcons.userMinus,
                      size: 18, color: Colors.red),
                  onPressed: () => _confirmRemoveMember(context, member),
                ),
              ),
            ),
        ]),
    ];

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              controller: _tableScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _tableScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Table(
                    columnWidths: {
                      0: const IntrinsicTableSize(),
                      1: const IntrinsicTableSize(),
                      2: const IntrinsicTableSize(),
                      4: const IntrinsicTableSize(),
                      5: const IntrinsicTableSize(),
                      if (isTeacher) 6: const IntrinsicTableSize(),
                    },
                    rows: rows,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  TableCell _headerCell(String label, TableCellTheme cellTheme) {
    return TableCell(
      theme: cellTheme,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final provider = widget.provider;
    showResponsiveDialog(
      context,
      builder: (ctx, _) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
            'Are you sure you want to delete "${widget.classResponse.name}"? '
            'This action cannot be undone.'),
        actions: [
          Button.ghost(
            onPressed: () => closeOverlay(ctx),
            child: const Text('Cancel'),
          ),
          Button.destructive(
            onPressed: () async {
              final success =
                  await provider.deleteClass(widget.classResponse.id);
              if (ctx.mounted) {
                closeOverlay(ctx);
                if (success) {
                  if (context.mounted) {
                    context.go('/classes');
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'Failed to delete class'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, MemberResponse member) {
    showResponsiveDialog(
      context,
      builder: (ctx, _) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${member.email} from this class?'),
        actions: [
          Button.ghost(
            onPressed: () => closeOverlay(ctx),
            child: const Text('Cancel'),
          ),
          Button.destructive(
            onPressed: () async {
              final success = await _provider.removeMember(
                widget.classResponse.id,
                member.userId,
              );
              if (ctx.mounted) {
                safeCloseOverlay(ctx);
                if (success) {
                  setState(() {
                    _rosterFuture =
                        _provider.loadRoster(widget.classResponse.id);
                  });
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(_provider.error ?? 'Failed to remove member'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    showResponsiveDialog(
      context,
      builder: (ctx, _) => _AddMemberDialog(
        classId: widget.classResponse.id,
        provider: _provider,
        apiClient: _provider.apiClient,
        onMemberAdded: () {
          setState(() {
            _rosterFuture = _provider.loadRoster(widget.classResponse.id);
          });
        },
      ),
    );
  }

  String _formatJoined(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return OutlineBadge(
      child: Text(role),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final int classId;
  final ClassProvider provider;
  final ApiClient apiClient;
  final VoidCallback onMemberAdded;

  const _AddMemberDialog({
    required this.classId,
    required this.provider,
    required this.apiClient,
    required this.onMemberAdded,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  late final UserService _service;

  @override
  void initState() {
    super.initState();
    _service = UserService(widget.apiClient);
  }

  int? _selectedUserId;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_selectedUserId == null) return;

    setState(() => _isSubmitting = true);

    final success = await widget.provider.addMember(
      widget.classId,
      _selectedUserId!,
    );

    if (mounted) {
      if (success) {
        widget.onMemberAdded();
        safeCloseOverlay(context);
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.provider.error ?? 'Failed to add member'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Member'),
      content: SizedBox(
        width: 400,
        child: ShadcnSearchDropdown<SearchResult>(
          hintText: 'Search users',
          loader: (query) async => _service.searchUsers(query),
          itemBuilder: (context, user) =>
              Text('${user.displayName} (${user.email})'),
          onChanged: (user) => setState(() => _selectedUserId = user?.id),
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
              : const Text('Add'),
        ),
      ],
    );
  }
}
