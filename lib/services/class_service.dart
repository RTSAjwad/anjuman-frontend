import '../config/api_config.dart';
import '../models/class.dart';
import 'api_client.dart';

class ClassService {
  final ApiClient _client;

  ClassService(this._client);

  Future<List<ClassResponse>> listClasses() async {
    final list = await _client.getList(ApiConfig.classes);
    return list.map((c) => ClassResponse.fromJson(c)).toList();
  }

  Future<ClassResponse> createClass(CreateClass createClass) async {
    final json =
        await _client.post(ApiConfig.classes, body: createClass.toJson());
    return ClassResponse.fromJson(json);
  }

  Future<dynamic> deleteClass(int id) async {
    return _client.delete(ApiConfig.classById(id));
  }

  Future<ClassResponse> renameClass(int id, String name) async {
    final body = RenameClass(name: name);
    final json =
        await _client.patch(ApiConfig.classRename(id), body: body.toJson());
    return ClassResponse.fromJson(json);
  }

  Future<ClassResponse> archiveClass(int id) async {
    final json = await _client.post(ApiConfig.classArchive(id));
    return ClassResponse.fromJson(json);
  }

  Future<RosterResponse> getRoster(int id) async {
    final json = await _client.getMap(ApiConfig.classRoster(id));
    return RosterResponse.fromJson(json);
  }

  Future<dynamic> addMember(int classId, int userId) async {
    final body = AddMember(userId: userId);
    return _client.post(ApiConfig.classMembers(classId), body: body.toJson());
  }

  Future<dynamic> removeMember(int classId, int userId) async {
    return _client.delete(ApiConfig.classMember(classId, userId));
  }
}
