import '../config/api_config.dart';
import '../models/study.dart';
import 'api_client.dart';

class StudyService {
  final ApiClient _client;

  StudyService(this._client);

  Future<StudySession> getDeckStudy(int deckId) async {
    final json = await _client.getMap(ApiConfig.deckStudy(deckId));
    return StudySession.fromJson(json);
  }

  Future<ReviewResponse> submitReview(SubmitReview review) async {
    final json = await _client.post(ApiConfig.reviews, body: review.toJson());
    return ReviewResponse.fromJson(json);
  }
}
