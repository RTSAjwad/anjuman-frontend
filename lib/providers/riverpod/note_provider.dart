import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card_record.dart';
import '../../models/deck.dart';
import '../../models/note_record.dart';
import '../../services/note_service.dart';
import 'api_client_provider.dart';
import 'card_store_provider.dart' as card_store;
import 'note_store_provider.dart' as note_store;

/// Immutable note-gateway state.
class NoteState {
  final bool isLoading;
  final String? error;

  const NoteState({this.isLoading = false, this.error});

  NoteState copyWith(
      {bool? isLoading, String? error, bool clearError = false}) {
    return NoteState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod replacement for the legacy `NoteProvider`.
///
/// Thin gateway over the note-centric `/notes` endpoints, writing results into
/// the Riverpod note/card stores so note changes propagate everywhere.
class NoteNotifier extends Notifier<NoteState> {
  late final NoteService _noteService;

  @override
  NoteState build() {
    _noteService = NoteService(ref.read(apiClientProvider));
    return const NoteState();
  }

  note_store.NoteStore get _noteStore =>
      ref.read(note_store.noteStoreProvider.notifier);
  card_store.CardStore get _cardStore =>
      ref.read(card_store.cardStoreProvider.notifier);

  bool get isLoading => state.isLoading;
  String? get error => state.error;

  NoteRecord? note(int noteId) => _noteStore.note(noteId);

  Future<List<NoteRecord>> listNotes({int? deckId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final notes = await _noteService.listNotes(deckId: deckId);
      _noteStore.upsertNotes(notes.map(_toNoteRecord));
      for (final n in notes) {
        for (final c in n.cards) {
          _cardStore.upsertCard(_cardFrom(n, c));
        }
      }
      return notes.map(_toNoteRecord).toList();
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    } finally {
      state = state.copyWith(isLoading: false);
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
      state = state.copyWith(error: e.toString());
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
      state = state.copyWith(error: e.toString());
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
      state = state.copyWith(error: e.toString());
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

/// The shared note gateway provider.
final noteProvider =
    NotifierProvider<NoteNotifier, NoteState>(NoteNotifier.new);
