import '../config/api_config.dart';
import '../models/analytics.dart';
import 'api_client.dart';

class AnalyticsService {
  final ApiClient _client;

  AnalyticsService(this._client);

  Future<StudentStats> getMyStats() async {
    final json = await _client.getMap(ApiConfig.analyticsMe);
    return StudentStats.fromJson(json);
  }

  Future<List<DailyPoint>> getMyDaily() async {
    final list = await _client.getList(ApiConfig.analyticsMeDaily);
    return list.map((d) => DailyPoint.fromJson(d)).toList();
  }

  Future<ClassAnalytics> getClassAnalytics(int classId) async {
    final json = await _client.getMap(ApiConfig.analyticsClass(classId));
    return ClassAnalytics.fromJson(json);
  }

  Future<StudentDetail> getStudentDetail(int classId, int studentId) async {
    final json =
        await _client.getMap(ApiConfig.analyticsStudent(classId, studentId));
    return StudentDetail.fromJson(json);
  }

  Future<DashboardResponse> getDashboard() async {
    final json = await _client.getMap(ApiConfig.dashboard);
    return DashboardResponse.fromJson(json);
  }
}
