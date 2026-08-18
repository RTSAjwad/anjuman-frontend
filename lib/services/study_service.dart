import '../config/api_config.dart';
import '../models/study.dart';
import 'api_client.dart';

class StudyService {
  final ApiClient _client;

  StudyService(this._client);

  /// Starts (or refreshes) the study flow for a deck.
  ///
  /// `GET /decks/{id}/study` returns the next due card (or null) plus fresh
  /// counts. No body.
  Future<StudyResponse> startStudy(int deckId) async {
    final json = await _client.getMap(ApiConfig.deckStudy(deckId));
    return StudyResponse.fromJson(json);
  }

  /// Submits a rating for the current card and advances the flow.
  ///
  /// `POST /decks/{id}/study` returns the same shape with `reviewed_card` set
  /// to the post-review state of the answered card.
  Future<StudyResponse> submitReview(int deckId, SubmitReview review) async {
    final json = await _client.post(
      ApiConfig.deckStudy(deckId),
      body: review.toJson(),
    );
    return StudyResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> setCardFlag(int cardId, int flag) async {
    final json =
        await _client.patch(ApiConfig.cardFlag(cardId), body: {'flag': flag});
    return json;
  }
}
