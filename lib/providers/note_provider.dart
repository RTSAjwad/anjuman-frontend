import 'package:flutter/foundation.dart';
import '../models/card_record.dart';
import '../models/deck.dart';
import '../models/note_record.dart';
import '../services/api_client.dart';
import '../services/note_service.dart';
import '../widgets/safe_notify.dart';
import 'card_store.dart';
import 'note_store.dart';

/// Thin gateway over the note-centric `/notes` endpoints, writing results into
/// [NoteStore] (and card records into [CardStore]) so note changes propagate
/// everywhere.
class NoteProvider extends ChangeNotifier with SafeNotify {
  final ApiClient _apiClient;
  late NoteStore _noteStore;
  late CardStore _cardStore;
  late final NoteService _noteService;

  bool _isLoading = false;
  String? _error;

  NoteProvider(this._apiClient, this._noteStore, this._cardStore) {
    _noteService = NoteService(_apiClient);
  }

  set noteStore(NoteStore value) => _noteStore = value;
  set cardStore(CardStore value) => _cardStore = value;

  bool get isLoading => _isLoading;
  String? get error => _error;

  NoteRecord? note(int noteId) => _noteStore.note(noteId);

  Future<List<NoteRecord>> listNotes({int? deckId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final notes = await _noteService.listNotes(deckId: deckId);
      // Upsert note records and the card records they reference (each card
      // carries its deck via CardSummary.deckId).
      _noteStore.upsertNotes(notes.map(_toNoteRecord));
      for (final n in notes) {
        for (final c in n.cards) {
          _cardStore.upsertCard(_cardFrom(n, c));
        }
      }
      return notes.map(_toNoteRecord).toList();
    } on Exception catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _isLoading = false;
      safeNotify();
    }
  }

  Future<NoteRecord?> createNote(CreateNote note) async {
    try {
      final n = await _noteService.createNote(note);
      _noteStore.upsertNote(_toNoteRecord(n));
      for (final c in n.cards) {
        _cardStore.upsertCard(_cardFrom(n, c));
      }
      return _toNoteRecord(n);
    } on Exception catch (e) {
      _error = e.toString();
      safeNotify();
      return null;
    }
  }

  Future<NoteRecord?> updateNote(int noteId, UpdateNote update) async {
    try {
      final n = await _noteService.updateNote(noteId, update);
      _noteStore.upsertNote(_toNoteRecord(n));
      for (final c in n.cards) {
        _cardStore.upsertCard(_cardFrom(n, c));
      }
      return _toNoteRecord(n);
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteNote(int noteId) async {
    try {
      final note = _noteStore.note(noteId);
      if (note != null) {
        for (final cardId in note.cardIds) {
          _cardStore.removeCard(cardId);
        }
      }
      await _noteService.deleteNote(noteId);
      _noteStore.removeNote(noteId);
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  NoteRecord _toNoteRecord(NoteResponse n) => NoteRecord(
        noteId: n.id,
        noteTypeId: n.noteTypeId,
        noteTypeName: n.noteTypeName,
        fields: n.fields,
        cardIds: n.cards.map((c) => c.id).toList(),
      );

  CardRecord _cardFrom(NoteResponse n, CardSummary c) => CardRecord(
        cardId: c.id,
        noteId: n.id,
        deckId: c.deckId ?? 0,
        deckTitle: '',
        front: c.front,
        back: c.back,
        noteTypeName: n.noteTypeName,
        fields: n.fields,
        templateIndex: c.templateIndex,
        templateName: c.templateName,
        stability: 0,
        difficulty: 0,
        reps: 0,
        lapses: 0,
      );
}
