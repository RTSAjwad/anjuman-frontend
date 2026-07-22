import '../config/api_config.dart';
import '../models/assignment.dart';
import 'api_client.dart';

class AssignmentService {
  final ApiClient _client;

  AssignmentService(this._client);

  Future<AssignmentResponse> createAssignment(
      int classId, CreateAssignment assignment) async {
    final json = await _client.post(ApiConfig.assignments(classId),
        body: assignment.toJson());
    return AssignmentResponse.fromJson(json);
  }

  Future<List<AssignmentResponse>> listAssignments(int classId) async {
    final list = await _client.getList(ApiConfig.assignments(classId));
    return list.map((a) => AssignmentResponse.fromJson(a)).toList();
  }

  Future<AssignmentDetailResponse> getAssignment(int id) async {
    final json = await _client.getMap(ApiConfig.assignmentById(id));
    return AssignmentDetailResponse.fromJson(json);
  }

  Future<AssignmentResponse> updateAssignment(
      int id, UpdateAssignment update) async {
    final json = await _client.patch(ApiConfig.assignmentById(id),
        body: update.toJson());
    return AssignmentResponse.fromJson(json);
  }

  Future<dynamic> deleteAssignment(int id) async {
    return _client.delete(ApiConfig.assignmentById(id));
  }

  Future<AssignmentResponse> publishAssignment(int id) async {
    final json = await _client.post(ApiConfig.assignmentPublish(id));
    return AssignmentResponse.fromJson(json);
  }

  Future<AssignmentResponse> archiveAssignment(int id) async {
    final json = await _client.post(ApiConfig.assignmentArchive(id));
    return AssignmentResponse.fromJson(json);
  }

  Future<dynamic> completeAssignment(int id) async {
    return _client.post(ApiConfig.assignmentComplete(id));
  }
}
