import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import 'api_client_provider.dart';

/// Immutable view state for the user provider.
///
/// Mirrors the mutable fields held by the legacy `UserProvider`, as an
/// immutable value so every change produces a new [UserState].
class UserState {
  final List<UserDetail> users;
  final bool isLoading;
  final String? error;

  const UserState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    List<UserDetail>? users,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Riverpod replacement for the legacy `UserProvider`.
///
/// Reads the shared [apiClientProvider] for API access, keeping the same
/// method signatures as the legacy provider.
class UserNotifier extends Notifier<UserState> {
  UserService get _userService => UserService(ref.read(apiClientProvider));

  List<UserDetail> get users => state.users;
  bool get isLoading => state.isLoading;
  String? get error => state.error;

  @override
  UserState build() => const UserState();

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final users = await _userService.listUsers();
      state = state.copyWith(users: users, isLoading: false);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createUser(int schoolId, String email, String password,
      String role, String firstName, String lastName) async {
    try {
      await _userService.createUser(CreateUser(
        schoolId: schoolId,
        email: email,
        password: password,
        role: role,
        firstName: firstName,
        lastName: lastName,
      ));
      await loadUsers();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateUser(int id,
      {String? email,
      String? password,
      String? role,
      String? firstName,
      String? lastName}) async {
    try {
      await _userService.updateUser(
          id,
          UpdateUser(
              email: email,
              password: password,
              role: role,
              firstName: firstName,
              lastName: lastName));
      await loadUsers();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await _userService.deleteUser(id);
      await loadUsers();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// The shared user provider.
final userProvider =
    NotifierProvider<UserNotifier, UserState>(UserNotifier.new);
