import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<UserProvider>().loadUsers(),
          ),
        ],
      ),
      body: Consumer<UserProvider>(
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
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text('Failed to load users',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(err,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
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
                  Icon(Icons.people_outline,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No users found', style: theme.textTheme.titleMedium),
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

          return RefreshIndicator(
            onRefresh: () => provider.loadUsers(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const SizedBox(width: 40),
                            _sortableHeader('ID', UserSortField.id),
                            _sortableHeader('First', UserSortField.firstName),
                            _sortableHeader('Last', UserSortField.lastName),
                            _sortableHeader('Email', UserSortField.email),
                            _sortableHeader('Role', UserSortField.role),
                            _sortableHeader('Created', UserSortField.created),
                            const SizedBox(width: 80),
                          ],
                        ),
                      ),
                      ...sorted.map((user) => _UserRow(
                            user: user,
                            onEdit: () => _showEditDialog(context, user),
                            onDelete: () => _confirmDelete(context, user),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_user',
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Create User'),
      ),
    );
  }

  Widget _sortableHeader(String label, UserSortField field) {
    return Expanded(
      flex: field == UserSortField.email
          ? 3
          : field == UserSortField.firstName ||
                  field == UserSortField.lastName ||
                  field == UserSortField.role
              ? 2
              : 1,
      child: SortableHeader(
        label: label,
        isActive: _sort.field == field,
        ascending: _sort.ascending,
        onTap: () => setState(() => _sort.toggle(field)),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final schoolId = auth.user?.schoolId ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => _UserFormDialog(
        title: 'Create User',
        provider: context.read<UserProvider>(),
        schoolId: schoolId,
        onSuccess: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showEditDialog(BuildContext context, UserDetail user) {
    showDialog(
      context: context,
      builder: (ctx) => _UserFormDialog(
        title: 'Edit User',
        provider: context.read<UserProvider>(),
        existingUser: user,
        onSuccess: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, UserDetail user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Delete ${user.displayName.isEmpty ? user.email : user.displayName}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final provider = context.read<UserProvider>();
              final success = await provider.deleteUser(user.id);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'Failed to delete user'),
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
}

class _UserRow extends StatelessWidget {
  final UserDetail user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserRow({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            child: Text(
              user.firstName.isNotEmpty
                  ? user.firstName[0].toUpperCase()
                  : user.email[0].toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _col(user.id.toString(), 1, theme),
          _col(user.firstName, 2, theme),
          _col(user.lastName, 2, theme),
          _col(user.email, 3, theme),
          Expanded(flex: 2, child: _RoleBadge(role: user.role)),
          _col(
              '${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}',
              2,
              theme,
              isSecondary: true),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: theme.colorScheme.error,
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _col(String text, int flex, ThemeData theme,
      {bool isSecondary = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isSecondary ? theme.colorScheme.onSurfaceVariant : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ignore: unused_element
  Color _roleColor(String role, ThemeData theme) {
    switch (role) {
      case 'admin':
        return theme.colorScheme.errorContainer;
      case 'teacher':
        return theme.colorScheme.primaryContainer;
      default:
        return theme.colorScheme.tertiaryContainer;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor;
    Color textColor;

    switch (role) {
      case 'admin':
        bgColor = theme.colorScheme.errorContainer;
        textColor = theme.colorScheme.onErrorContainer;
      case 'teacher':
        bgColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
      default:
        bgColor = theme.colorScheme.tertiaryContainer;
        textColor = theme.colorScheme.onTertiaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late String _role;
  bool _isSubmitting = false;

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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    bool success;
    if (_isEditing) {
      success = await widget.provider.updateUser(
        widget.existingUser!.id,
        email: _emailController.text.trim(),
        password:
            _passwordController.text.isEmpty ? null : _passwordController.text,
        role: _role,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
    } else {
      success = await widget.provider.createUser(
        widget.schoolId,
        _emailController.text.trim(),
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
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _isEditing ? 'New password (optional)' : 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outlined),
              ),
              validator: (value) {
                if (!_isEditing && (value == null || value.isEmpty)) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                DropdownMenuItem(value: 'student', child: Text('Student')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _role = value);
              },
            ),
          ],
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
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

enum UserSortField { id, firstName, lastName, email, role, created }
