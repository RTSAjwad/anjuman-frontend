import 'package:flutter/services.dart' show TextInputAction;
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _emailKey = TextFieldKey('email');
  static const _passwordKey = TextFieldKey('password');

  bool _isSubmitting = false;
  String? _error;

  Future<void> _handleSubmit(
      BuildContext context, Map<FormKey, dynamic> values) async {
    final email = _emailKey[values] ?? '';
    final password = _passwordKey[values] ?? '';

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.login(email, password);

    if (mounted && !success) {
      setState(() {
        _isSubmitting = false;
        _error = auth.error ?? 'Login failed';
      });
    }
  }

  void _quickLogin(String email, String password) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    await auth.login(email, password);
    if (mounted && auth.error != null) {
      setState(() {
        _isSubmitting = false;
        _error = auth.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: OutlinedContainer(
              padding: const EdgeInsets.all(32),
              child: Form(
                onSubmit: _handleSubmit,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(LucideIcons.graduationCap,
                        size: 64, color: colors.primary),
                    const SizedBox(height: 16),
                    const Text('Anki Classroom').semiBold(),
                    const SizedBox(height: 8),
                    Text('Sign in to continue',
                        style: TextStyle(color: colors.mutedForeground)),
                    const SizedBox(height: 32),
                    FormField<String>(
                      key: _emailKey,
                      label: const Text('Email', style: TextStyle(fontSize: 13))
                          .semiBold(),
                      validator: const LengthValidator(
                          min: 1, message: 'Email is required'),
                      showErrors: const {
                        FormValidationMode.changed,
                        FormValidationMode.submitted,
                      },
                      child: const TextField(
                        initialValue: '',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FormField<String>(
                      key: _passwordKey,
                      label:
                          const Text('Password', style: TextStyle(fontSize: 13))
                              .semiBold(),
                      validator: const LengthValidator(
                          min: 1, message: 'Password is required'),
                      showErrors: const {
                        FormValidationMode.changed,
                        FormValidationMode.submitted,
                      },
                      child: const TextField(
                        initialValue: '',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(
                              color: colors.destructive, fontSize: 13)),
                      const SizedBox(height: 12),
                    ],
                    FormErrorBuilder(
                      builder: (context, errors, child) {
                        return Button.primary(
                          onPressed: _isSubmitting || errors.isNotEmpty
                              ? null
                              : () => context.submitForm(),
                          trailing: _isSubmitting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                          child: const Text('Sign In'),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Button.outline(
                            onPressed: () =>
                                _quickLogin('admin@school1.com', 'admin123'),
                            leading: const Icon(LucideIcons.shield, size: 16),
                            child: const Text('Admin',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Button.outline(
                            onPressed: () =>
                                _quickLogin('teacher@school1.com', 'teach123'),
                            leading:
                                const Icon(LucideIcons.graduationCap, size: 16),
                            child: const Text('Teacher',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Button.outline(
                            onPressed: () =>
                                _quickLogin('student@school1.com', 'stud123'),
                            leading: const Icon(LucideIcons.user, size: 16),
                            child: const Text('Student',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
