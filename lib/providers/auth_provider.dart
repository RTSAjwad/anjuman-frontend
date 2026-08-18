import 'package:flutter/foundation.dart';
import '../models/auth.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  late final AuthService authService;

  UserInfo? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  AuthProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient() {
    authService = AuthService(_apiClient);
  }

  UserInfo? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ApiClient get apiClient => _apiClient;

  String get role => _user?.role ?? 'student';

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await authService.login(email, password);
      _token = response.token;
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await authService.logout();
    } catch (_) {
      // Logout locally even if the API call fails
    }
    _token = null;
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
