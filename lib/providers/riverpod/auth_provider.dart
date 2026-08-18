import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/auth.dart';
import '../../services/auth_service.dart';
import 'api_client_provider.dart';

/// Immutable authentication state.
class AuthState {
  final UserInfo? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null;

  String get role => user?.role ?? 'student';

  AuthState copyWith({
    UserInfo? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
    bool clearToken = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod replacement for the legacy `AuthProvider`.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;

  @override
  AuthState build() {
    _authService = AuthService(ref.read(apiClientProvider));
    return const AuthState();
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.login(email, password);
      ref.read(apiClientProvider).setToken(response.token);
      state = state.copyWith(
        user: response.user,
        token: response.token,
        isLoading: false,
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {
      // Logout locally even if the API call fails
    }
    ref.read(apiClientProvider).setToken(null);
    state = state.copyWith(
      clearUser: true,
      clearToken: true,
      clearError: true,
      isLoading: false,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// The shared auth provider.
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
