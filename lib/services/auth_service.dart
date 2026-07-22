import '../config/api_config.dart';
import '../models/auth.dart';
import '../models/common.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<LoginResponse> login(String email, String password) async {
    final body = LoginRequest(email: email, password: password);
    final json = await _client.post(ApiConfig.login, body: body.toJson());
    final response = LoginResponse.fromJson(json);
    _client.setToken(response.token);
    return response;
  }

  Future<MessageResponse> logout() async {
    final json = await _client.post(ApiConfig.logout);
    _client.setToken(null);
    return MessageResponse.fromJson(json);
  }

  bool get isAuthenticated => _client.token != null;
}
