import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  late final UserService _userService;

  UserProvider(this._apiClient) {
    _userService = UserService(_apiClient);
  }

  List<UserDetail> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserDetail> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await _userService.listUsers();
      _users = list;
    } on Exception catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
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
      _error = e.toString();
      notifyListeners();
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
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await _userService.deleteUser(id);
      await loadUsers();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
