import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../models/class.dart';
import '../models/search_result.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';
import '../widgets/sortable_table.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassResponse classResponse;
  final ClassProvider provider;

  const ClassDetailScreen(
      {super.key, required this.classResponse, required this.provider});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  late Future<RosterResponse?> _rosterFuture;
  final _sort =
      TableSort<MemberResponse, MemberSortField>(MemberSortField.email, true);

  @override
  void initState() {
    super.initState();
    _rosterFuture = widget.provider.loadRoster(widget.classResponse.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTeacher = auth.role == 'teacher' || auth.role == 'admin';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classResponse.name),
        actions: [
          if (isTeacher)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'delete') {
                  _confirmDelete(context);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Class', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<RosterResponse?>(
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
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load roster',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() {
                        _rosterFuture =
                            widget.provider.loadRoster(widget.classResponse.id);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Members section
                Row(
                  children: [
                    Text(
                      'Members',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _InfoChip(
                      icon: Icons.school_outlined,
                      label:
                          '$teacherCount teacher${teacherCount == 1 ? '' : 's'}',
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.people_outline,
                      label:
                          '$studentCount student${studentCount == 1 ? '' : 's'}',
                      color: theme.colorScheme.tertiary,
                    ),
                    const Spacer(),
                    if (isTeacher)
                      FilledButton.tonalIcon(
                        onPressed: () => _showAddMemberDialog(context),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Member list
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Table header
                      Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 3,
                              child: SortableHeader(
                                label: 'Email',
                                isActive: _sort.field == MemberSortField.email,
                                ascending: _sort.ascending,
                                onTap: () => setState(
                                    () => _sort.toggle(MemberSortField.email)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: SortableHeader(
                                label: 'Role',
                                isActive: _sort.field == MemberSortField.role,
                                ascending: _sort.ascending,
                                onTap: () => setState(
                                    () => _sort.toggle(MemberSortField.role)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: SortableHeader(
                                label: 'Joined',
                                isActive: _sort.field == MemberSortField.joined,
                                ascending: _sort.ascending,
                                onTap: () => setState(
                                    () => _sort.toggle(MemberSortField.joined)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._sort
                          .sort(
                              members,
                              (m, f) => switch (f) {
                                    MemberSortField.email => m.email,
                                    MemberSortField.role => m.role,
                                    MemberSortField.joined => m.joinedAt,
                                  })
                          .map((member) => _MemberRow(
                                member: member,
                                canRemove: isTeacher,
                                onRemove: () =>
                                    _confirmRemoveMember(context, member),
                              )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final provider = widget.provider;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
            'Are you sure you want to delete "${widget.classResponse.name}"? '
            'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final success =
                  await provider.deleteClass(widget.classResponse.id);
              if (ctx.mounted) {
                Navigator.of(ctx).pop(); // close dialog
                if (success) {
                  Navigator.of(context).pop(); // go back to class list
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${member.email} from this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final success = await widget.provider.removeMember(
                widget.classResponse.id,
                member.userId,
              );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (success) {
                  setState(() {
                    _rosterFuture =
                        widget.provider.loadRoster(widget.classResponse.id);
                  });
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          widget.provider.error ?? 'Failed to remove member'),
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
    showDialog(
      context: context,
      builder: (ctx) => _AddMemberDialog(
        classId: widget.classResponse.id,
        provider: widget.provider,
        apiClient: widget.provider.apiClient,
        onMemberAdded: () {
          setState(() {
            _rosterFuture = widget.provider.loadRoster(widget.classResponse.id);
          });
        },
      ),
    );
  }

  // ignore: unused_element
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final MemberResponse member;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.member,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTeacher = member.role == 'teacher';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isTeacher
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.tertiaryContainer,
            child: Text(
              member.firstName.isNotEmpty
                  ? member.firstName[0].toUpperCase()
                  : member.email[0].toUpperCase(),
              style: TextStyle(
                color: isTeacher
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName.isEmpty
                      ? member.email
                      : member.displayName,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (member.displayName.isNotEmpty)
                  Text(
                    member.email,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isTeacher
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                member.role,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isTeacher
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatJoined(member.joinedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (canRemove)
            SizedBox(
              width: 40,
              child: IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: theme.colorScheme.error,
                tooltip: 'Remove member',
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }

  String _formatJoined(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
    final service = UserService(widget.apiClient);
    return AlertDialog(
      title: const Text('Add Member'),
      content: SizedBox(
        width: 400,
        child: DropdownSearch<SearchResult>(
          items: (filter, _) async => service.searchUsers(filter),
          compareFn: (a, b) => a.id == b.id,
          itemAsString: (u) => '${u.displayName} ${u.email}',
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchDelay: const Duration(milliseconds: 300),
            itemBuilder: (ctx, user, isDisabled, isSelected) {
              return ListTile(
                title: Text(user.displayName),
                subtitle: Text(user.email),
              );
            },
          ),
          onSelected: (user) => _selectedUserId = user?.id,
          decoratorProps: const DropDownDecoratorProps(
            decoration: InputDecoration(
              labelText: 'Search user',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
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
              : const Text('Add'),
        ),
      ],
    );
  }
}

enum MemberSortField { email, role, joined }
