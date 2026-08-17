import '../config/api_config.dart';
import '../models/deck.dart';
import 'api_client.dart';

/// HTTP client for the note-centric `/notes` endpoints.
class NoteService {
  final ApiClient _client;

  NoteService(this._client);

  Future<NoteResponse> createNote(CreateNote note) async {
    final json = await _client.post(ApiConfig.notes, body: note.toJson());
    return NoteResponse.fromJson(json);
  }

  Future<List<NoteResponse>> listNotes({int? deckId}) async {
    final path =
        deckId != null ? ApiConfig.notesByDeck(deckId) : ApiConfig.notes;
    final list = await _client.getList(path);
    return list.map((n) => NoteResponse.fromJson(n)).toList();
  }

  Future<NoteResponse> getNote(int noteId) async {
    final json = await _client.getMap(ApiConfig.note(noteId));
    return NoteResponse.fromJson(json);
  }

  Future<NoteResponse> updateNote(int noteId, UpdateNote update) async {
    final json =
        await _client.patch(ApiConfig.note(noteId), body: update.toJson());
    return NoteResponse.fromJson(json);
  }

  Future<dynamic> deleteNote(int noteId) async {
    return _client.delete(ApiConfig.note(noteId));
  }
}
