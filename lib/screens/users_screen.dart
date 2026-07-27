import 'package:flutter/material.dart'
    show Colors, ScaffoldMessenger, SnackBar, SnackBarBehavior;
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import '../widgets/sortable_table.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _sort =
      TableSort<UserDetail, UserSortField>(UserSortField.lastName, true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Users'),
          trailing: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.userPlus, size: 20),
              onPressed: () => _showCreateDialog(context),
            ),
            IconButton.ghost(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: () => context.read<UserProvider>().loadUsers(),
            ),
          ],
        ),
      ],
      child: Consumer<UserProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.users.isEmpty) {
            final err = provider.error!;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.circleAlert,
                        size: 48, color: colors.destructive),
                    const SizedBox(height: 16),
                    const Text('Failed to load users'),
                    const SizedBox(height: 8),
                    Text(err,
                        style: TextStyle(
                            color: colors.mutedForeground, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Button.secondary(
                      onPressed: () => provider.loadUsers(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.users,
                      size: 64, color: colors.mutedForeground),
                  const SizedBox(height: 16),
                  const Text('No users found'),
                ],
              ),
            );
          }

          final sorted = _sort.sort(
              provider.users,
              (u, f) => switch (f) {
                    UserSortField.id => u.id,
                    UserSortField.firstName => u.firstName,
                    UserSortField.lastName => u.lastName,
                    UserSortField.email => u.email,
                    UserSortField.role => u.role,
                    UserSortField.created => u.createdAt,
                  });

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: OutlinedContainer(
                    child: Table(
                      columnWidths: {
                        0: const IntrinsicTableSize(),
                        1: const FlexTableSize(),
                        2: const FlexTableSize(),
                        3: const FlexTableSize(flex: 3),
                        4: const IntrinsicTableSize(),
                        5: const IntrinsicTableSize(),
                        6: const IntrinsicTableSize(),
                      },
                      rows: [
                        TableHeader(cells: [
                          TableCell(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Text('',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ),
                          ),
                          TableCell(
                              child:
                                  _sortCell('First', UserSortField.firstName)),
                          TableCell(
                              child: _sortCell('Last', UserSortField.lastName)),
                          TableCell(
                              child: _sortCell('Email', UserSortField.email)),
                          TableCell(
                              child: _sortCell('Role', UserSortField.role)),
                          TableCell(
                              child:
                                  _sortCell('Created', UserSortField.created)),
                          const TableCell(
                            child: SizedBox(width: 80),
                          ),
                        ]),
                        for (final user in sorted)
                          TableRow(cells: [
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Avatar(
                                  size: 28,
                                  borderRadius: 14,
                                  initials: user.firstName.isNotEmpty
                                      ? user.firstName[0].toUpperCase()
                                      : user.email[0].toUpperCase(),
                                ),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(user.firstName,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(user.lastName,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(user.email,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: colors.mutedForeground)),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _RoleBadge(role: user.role),
                                ),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}',
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      TextStyle(color: colors.mutedForeground),
                                ),
                              ),
                            ),
                            TableCell(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.ghost(
                                    icon: const Icon(LucideIcons.pencil,
                                        size: 18),
                                    onPressed: () =>
                                        _showEditDialog(context, user),
                                  ),
                                  IconButton.ghost(
                                    icon: const Icon(LucideIcons.trash2,
                                        size: 18, color: Colors.red),
                                    onPressed: () =>
                                        _confirmDelete(context, user),
                                  ),
                                ],
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

  Widget _sortCell(String label, UserSortField field) {
    final active = _sort.field == field;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _sort.toggle(field)),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.mutedForeground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active)
              Icon(
                _sort.ascending ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final schoolId = auth.user?.schoolId ?? 0;
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => _UserFormDialog(
          title: 'Create User',
          provider: context.read<UserProvider>(),
          schoolId: schoolId,
          onSuccess: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, UserDetail user) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => _UserFormDialog(
          title: 'Edit User',
          provider: context.read<UserProvider>(),
          existingUser: user,
          onSuccess: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, UserDetail user) {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => AlertDialog(
          title: const Text('Delete User'),
          content: Text(
              'Delete ${user.displayName.isEmpty ? user.email : user.displayName}? This cannot be undone.'),
          actions: [
            Button.ghost(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            Button.destructive(
              onPressed: () async {
                final provider = context.read<UserProvider>();
                final success = await provider.deleteUser(user.id);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(provider.error ?? 'Failed to delete user'),
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

class _UserFormDialog extends StatefulWidget {
  final String title;
  final UserProvider provider;
  final UserDetail? existingUser;
  final int schoolId;
  final VoidCallback onSuccess;

  const _UserFormDialog({
    required this.title,
    required this.provider,
    this.existingUser,
    this.schoolId = 0,
    required this.onSuccess,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late String _role;
  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.existingUser?.firstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.existingUser?.lastName ?? '');
    _emailController =
        TextEditingController(text: widget.existingUser?.email ?? '');
    _passwordController = TextEditingController();
    _role = widget.existingUser?.role ?? 'student';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Manual validation
    if (_firstNameController.text.trim().isEmpty) {
      setState(() => _error = 'First name is required');
      return;
    }
    if (_lastNameController.text.trim().isEmpty) {
      setState(() => _error = 'Last name is required');
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email is required');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    if (!_isEditing && _passwordController.text.isEmpty) {
      setState(() => _error = 'Password is required');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    bool success;
    if (_isEditing) {
      success = await widget.provider.updateUser(
        widget.existingUser!.id,
        email: email,
        password:
            _passwordController.text.isEmpty ? null : _passwordController.text,
        role: _role,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
    } else {
      success = await widget.provider.createUser(
        widget.schoolId,
        email,
        _passwordController.text,
        _role,
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
      );
    }

    if (mounted) {
      if (success) {
        widget.onSuccess();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.provider.error ?? 'Operation failed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('First Name', style: TextStyle(fontSize: 13))
                          .semiBold(),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _firstNameController,
                        placeholder: const Text('First Name'),
                        initialValue: _firstNameController.text,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Last Name', style: TextStyle(fontSize: 13))
                          .semiBold(),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _lastNameController,
                        placeholder: const Text('Last Name'),
                        initialValue: _lastNameController.text,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Email', style: TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              placeholder: const Text('Email'),
              initialValue: _emailController.text,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Text(_isEditing ? 'New password (optional)' : 'Password',
                    style: const TextStyle(fontSize: 13))
                .semiBold(),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              placeholder:
                  Text(_isEditing ? 'Leave blank to keep current' : 'Password'),
              initialValue: '',
              obscureText: true,
            ),
            const SizedBox(height: 16),
            const Text('Role', style: const TextStyle(fontSize: 13)).semiBold(),
            const SizedBox(height: 6),
            Select<String>(
              value: _role,
              placeholder: const Text('Select role'),
              onChanged: (value) {
                if (value != null) setState(() => _role = value);
              },
              popup: const SelectPopup(
                items: SelectItemList(children: [
                  SelectItemButton(value: 'admin', child: Text('Admin')),
                  SelectItemButton(value: 'teacher', child: Text('Teacher')),
                  SelectItemButton(value: 'student', child: Text('Student')),
                ]),
              ),
              itemBuilder: (context, value) =>
                  Text(value[0].toUpperCase() + value.substring(1)),
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
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

enum UserSortField { id, firstName, lastName, email, role, created }
