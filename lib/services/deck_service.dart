import '../config/api_config.dart';
import '../models/class_info.dart';
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
      {String? title, String? description}) async {
    final body = UpdateDeck(title: title, description: description);
    final json =
        await _client.patch(ApiConfig.deckUpdate(id), body: body.toJson());
    return DeckResponse.fromJson(json);
  }

  Future<DeckResponse> duplicateDeck(int id) async {
    final json = await _client.post(ApiConfig.deckDuplicate(id));
    return DeckResponse.fromJson(json);
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

  // Notes

  Future<NoteResponse> createNote(int deckId, CreateNote note) async {
    final json =
        await _client.post(ApiConfig.notes(deckId), body: note.toJson());
    return NoteResponse.fromJson(json);
  }

  Future<List<NoteResponse>> listNotes(int deckId) async {
    final list = await _client.getList(ApiConfig.notes(deckId));
    return list.map((n) => NoteResponse.fromJson(n)).toList();
  }

  Future<NoteResponse> getNote(int deckId, int noteId) async {
    final json = await _client.getMap(ApiConfig.note(deckId, noteId));
    return NoteResponse.fromJson(json);
  }

  Future<NoteResponse> updateNote(
      int deckId, int noteId, UpdateNote update) async {
    final json = await _client.patch(ApiConfig.note(deckId, noteId),
        body: update.toJson());
    return NoteResponse.fromJson(json);
  }

  Future<dynamic> deleteNote(int deckId, int noteId) async {
    return _client.delete(ApiConfig.note(deckId, noteId));
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
}
