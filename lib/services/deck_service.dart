import '../config/api_config.dart';
import '../models/class_info.dart';
import '../models/common.dart';
import '../models/deck.dart';
import 'api_client.dart';

class DeckService {
  final ApiClient _client;

  DeckService(this._client);

  Future<List<DeckResponse>> listDecks() async {
    final list = await _client.getList(ApiConfig.decks);
    return list.map((d) => DeckResponse.fromJson(d)).toList();
  }

  Future<DeckResponse> createDeck(CreateDeck deck) async {
    final json = await _client.post(ApiConfig.decks, body: deck.toJson());
    return DeckResponse.fromJson(json);
  }

  Future<DeckDetailResponse> getDeck(int id) async {
    final json = await _client.getMap(ApiConfig.deckById(id));
    return DeckDetailResponse.fromJson(json);
  }

  Future<dynamic> deleteDeck(int id) async {
    return _client.delete(ApiConfig.deckById(id));
  }

  Future<DeckResponse> renameDeck(int id, String title) async {
    final body = RenameDeck(title: title);
    final json =
        await _client.patch(ApiConfig.deckRename(id), body: body.toJson());
    return DeckResponse.fromJson(json);
  }

  Future<DeckResponse> updateDeck(int id,
      {String? title, String? description, int? parentId}) async {
    final body =
        UpdateDeck(title: title, description: description, parentId: parentId);
    final json =
        await _client.patch(ApiConfig.deckRename(id), body: body.toJson());
    return DeckResponse.fromJson(json);
  }

  Future<DeckResponse> duplicateDeck(int id) async {
    final json = await _client.post(ApiConfig.deckDuplicate(id));
    return DeckResponse.fromJson(json);
  }

  Future<DeckResponse> moveDeck(int id, int? parentId) async {
    final json = await _client
        .patch(ApiConfig.deckRename(id), body: {'parent_id': parentId});
    try {
      return DeckResponse.fromJson(json);
    } catch (e) {
      throw ApiException(500, 'Failed to parse deck response: $e');
    }
  }

  Future<dynamic> shareDeck(int deckId, int userId) async {
    final body = ShareDeck(userId: userId);
    return _client.post(ApiConfig.deckShare(deckId), body: body.toJson());
  }

  Future<dynamic> unshareDeck(int deckId, int userId) async {
    return _client.delete(ApiConfig.deckUnshare(deckId, userId));
  }

  Future<DeckResponse> transferOwner(int deckId, int userId) async {
    final json = await _client
        .patch(ApiConfig.deckOwner(deckId), body: {'user_id': userId});
    return DeckResponse.fromJson(json);
  }

  Future<dynamic> addDeckToClass(int deckId, int classId) async {
    return _client
        .post(ApiConfig.deckClasses(deckId), body: {'class_id': classId});
  }

  Future<List<ClassInfo>> listDeckClasses(int deckId) async {
    final list = await _client.getList(ApiConfig.deckClasses(deckId));
    return list.map((c) => ClassInfo.fromJson(c)).toList();
  }

  Future<dynamic> removeDeckFromClass(int deckId, int classId) async {
    return _client.delete(ApiConfig.deckClass(deckId, classId));
  }

  // Note Types

  Future<List<NoteType>> listNoteTypes() async {
    final list = await _client.getList(ApiConfig.noteTypes);
    return list.map((t) => NoteType.fromJson(t)).toList();
  }

  Future<NoteType> createNoteType(CreateNoteType noteType) async {
    final json =
        await _client.post(ApiConfig.noteTypes, body: noteType.toJson());
    return NoteType.fromJson(json);
  }

  Future<void> deleteNoteType(int id) async {
    await _client.delete(ApiConfig.noteTypeById(id));
  }

  Future<NoteType> updateNoteType(int id, CreateNoteType noteType) async {
    final json = await _client.patch(ApiConfig.noteTypeById(id),
        body: noteType.toJson());
    return NoteType.fromJson(json);
  }
}
