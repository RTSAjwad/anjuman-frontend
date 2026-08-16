import '../config/api_config.dart';
import 'api_client.dart';

/// Client for Anki-style card/note scheduling actions (suspend, bury,
/// reschedule). These are per-student operations, distinct from editing card
/// content.
class CardService {
  final ApiClient _client;

  CardService(this._client);

  Future<Map<String, dynamic>> suspendCard(int cardId) =>
      _client.post(ApiConfig.cardSuspend(cardId));

  Future<Map<String, dynamic>> unsuspendCard(int cardId) =>
      _client.post(ApiConfig.cardUnsuspend(cardId));

  Future<Map<String, dynamic>> buryCard(int cardId) =>
      _client.post(ApiConfig.cardBury(cardId));

  Future<Map<String, dynamic>> unburyCard(int cardId) =>
      _client.post(ApiConfig.cardUnbury(cardId));

  Future<Map<String, dynamic>> rescheduleCard({
    required int cardId,
    int? days,
    int? dueAt,
  }) {
    final body = <String, dynamic>{
      if (days != null) 'days': days,
      if (dueAt != null) 'due_at': dueAt,
    };
    return _client.patch(ApiConfig.cardReschedule(cardId), body: body);
  }

  Future<Map<String, dynamic>> suspendNote(int noteId) =>
      _client.post(ApiConfig.noteSuspend(noteId));

  Future<Map<String, dynamic>> buryNote(int noteId) =>
      _client.post(ApiConfig.noteBury(noteId));
}
