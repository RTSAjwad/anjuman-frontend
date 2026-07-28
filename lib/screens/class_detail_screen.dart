import 'package:flutter/material.dart'
    show Colors, ScaffoldMessenger, SnackBar, SnackBarBehavior;
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../models/class.dart';
import '../models/search_result.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';
import '../widgets/shadcn_search_dropdown.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassResponse classResponse;
  final ClassProvider provider;
  final bool embedded;
  final VoidCallback? onClose;

  const ClassDetailScreen({
    super.key,
    required this.classResponse,
    required this.provider,
    this.embedded = false,
    this.onClose,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  late Future<RosterResponse?> _rosterFuture;

  late ClassProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _rosterFuture = _provider.loadRoster(widget.classResponse.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTeacher = auth.role == 'teacher' || auth.role == 'admin';
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        AppBar(
          leading: [
            if (!widget.embedded)
              IconButton.outline(
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
          title: Text(widget.classResponse.name),
          trailing: [
            if (isTeacher)
              IconButton.outline(
                icon:
                    const Icon(LucideIcons.trash2, size: 20, color: Colors.red),
                onPressed: () => _confirmDelete(context),
              ),
          ],
        ),
      ],
      child: FutureBuilder<RosterResponse?>(
        future: _rosterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.circleAlert,
                      size: 48, color: colors.destructive),
                  const SizedBox(height: 16),
                  const Text('Failed to load roster'),
                  const SizedBox(height: 8),
                  Button.secondary(
                    onPressed: () {
                      setState(() {
                        _rosterFuture =
                            _provider.loadRoster(widget.classResponse.id);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final roster = snapshot.data!;
          final members = roster.members;

          final teacherCount = members.where((m) => m.role == 'teacher').length;
          final studentCount = members.where((m) => m.role == 'student').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with counts + add button
                  Row(
                    children: [
                      const Text('Members').semiBold(),
                      const SizedBox(width: 16),
                      OutlineBadge(
                        leading:
                            const Icon(LucideIcons.graduationCap, size: 14),
                        child: Text(
                            '$teacherCount teacher${teacherCount == 1 ? '' : 's'}'),
                      ),
                      const SizedBox(width: 12),
                      OutlineBadge(
                        leading: const Icon(LucideIcons.users, size: 14),
                        child: Text(
                            '$studentCount student${studentCount == 1 ? '' : 's'}'),
                      ),
                      const Spacer(),
                      if (isTeacher)
                        Button.secondary(
                          leading: const Icon(LucideIcons.userPlus, size: 18),
                          onPressed: () => _showAddMemberDialog(context),
                          child: const Text('Add'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Member table
                  OutlinedContainer(
                    child: Table(
                      columnWidths: {
                        0: const IntrinsicTableSize(),
                        1: const IntrinsicTableSize(),
                        2: const IntrinsicTableSize(),
                        4: const IntrinsicTableSize(),
                        5: const IntrinsicTableSize(),
                        if (isTeacher) 6: const IntrinsicTableSize(),
                      },
                      rows: [
                        TableHeader(cells: [
                          TableCell(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Text('',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          _headerCell('First Name'),
                          _headerCell('Last Name'),
                          _headerCell('Email'),
                          _headerCell('Role'),
                          _headerCell('Joined'),
                          if (isTeacher)
                            const TableCell(
                              child: SizedBox(width: 48),
                            ),
                        ]),
                        for (final member in members)
                          TableRow(cells: [
                            TableCell(
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
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                alignment: Alignment.centerLeft,
                                child: Text(member.firstName,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                alignment: Alignment.centerLeft,
                                child: Text(member.lastName,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                alignment: Alignment.centerLeft,
                                child: Text(member.email,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: colors.mutedForeground)),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                alignment: Alignment.centerLeft,
                                child: _RoleBadge(role: member.role),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _formatJoined(member.joinedAt),
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      TextStyle(color: colors.mutedForeground),
                                ),
                              ),
                            ),
                            if (isTeacher)
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: IconButton.ghost(
                                    icon: const Icon(LucideIcons.userMinus,
                                        size: 18, color: Colors.red),
                                    onPressed: () =>
                                        _confirmRemoveMember(context, member),
                                  ),
                                ),
                              ),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  TableCell _headerCell(String label) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final provider = widget.provider;
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Class'),
          content: Text(
              'Are you sure you want to delete "${widget.classResponse.name}"? '
              'This action cannot be undone.'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
              onPressed: () async {
                final success =
                    await provider.deleteClass(widget.classResponse.id);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  if (success) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(provider.error ?? 'Failed to delete class'),
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
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, MemberResponse member) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Remove ${member.email} from this class?'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
              onPressed: () async {
                final success = await _provider.removeMember(
                  widget.classResponse.id,
                  member.userId,
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
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
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => _AddMemberDialog(
          classId: widget.classResponse.id,
          provider: _provider,
          apiClient: _provider.apiClient,
          onMemberAdded: () {
            setState(() {
              _rosterFuture = _provider.loadRoster(widget.classResponse.id);
            });
          },
        ),
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
        Navigator.of(context).pop();
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
              : const Text('Add'),
        ),
      ],
    );
  }
}
