import '../config/api_config.dart';
import '../models/search_result.dart';
import '../models/user.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _client;

  UserService(this._client);

  Future<List<SearchResult>> searchUsers(String query) async {
    final list = await _client.getList(
        '${ApiConfig.userSearch}?q=${Uri.encodeQueryComponent(query)}');
    return list.map((u) => SearchResult.fromJson(u)).toList();
  }

  Future<List<UserDetail>> listUsers() async {
    final list = await _client.getList(ApiConfig.users);
    return list.map((u) => UserDetail.fromJson(u)).toList();
  }

  Future<MeResponse> getMe() async {
    final json = await _client.getMap(ApiConfig.me);
    return MeResponse.fromJson(json);
  }

  Future<User> createUser(CreateUser user) async {
    final json = await _client.post(ApiConfig.users, body: user.toJson());
    return User.fromJson(json);
  }

  Future<UserDetail> getUser(int id) async {
    final json = await _client.getMap(ApiConfig.user(id));
    return UserDetail.fromJson(json);
  }

  Future<User> updateUser(int id, UpdateUser update) async {
    final json = await _client.patch(ApiConfig.user(id), body: update.toJson());
    return User.fromJson(json);
  }

  Future<dynamic> deleteUser(int id) async {
    return _client.delete(ApiConfig.user(id));
  }
}
