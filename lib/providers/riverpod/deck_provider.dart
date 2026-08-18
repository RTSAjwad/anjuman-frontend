import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/common.dart';
import '../../models/deck.dart';
import '../../services/deck_service.dart';
import 'api_client_provider.dart';

/// Immutable view state for the deck provider.
///
/// Mirrors the mutable fields held by the legacy `DeckProvider`, as an
/// immutable value so every change produces a new [DeckState].
class DeckState {
  final List<DeckResponse> decks;
  final List<NoteType> noteTypes;
  final bool isLoading;
  final bool noteTypesLoading;
  final String? error;

  const DeckState({
    this.decks = const [],
    this.noteTypes = const [],
    this.isLoading = false,
    this.noteTypesLoading = false,
    this.error,
  });

  DeckState copyWith({
    List<DeckResponse>? decks,
    List<NoteType>? noteTypes,
    bool? isLoading,
    bool? noteTypesLoading,
    String? error,
  }) {
    return DeckState(
      decks: decks ?? this.decks,
      noteTypes: noteTypes ?? this.noteTypes,
      isLoading: isLoading ?? this.isLoading,
      noteTypesLoading: noteTypesLoading ?? this.noteTypesLoading,
      error: error ?? this.error,
    );
  }
}

/// Riverpod replacement for the legacy `DeckProvider`.
///
/// Reads the shared [apiClientProvider] for API access, keeping the same
/// method signatures as the legacy provider so consumers can swap over with
/// minimal change.
class DeckNotifier extends Notifier<DeckState> {
  DeckService get _deckService => DeckService(ref.read(apiClientProvider));

  // Convenience getters mirroring the legacy provider's public surface.
  List<DeckResponse> get decks => state.decks;
  bool get isLoading => state.isLoading;
  String? get error => state.error;
  List<NoteType> get noteTypes => state.noteTypes;
  bool get noteTypesLoading => state.noteTypesLoading;

  @override
  DeckState build() => const DeckState();

  Future<void> loadDecks() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final decks = await _deckService.listDecks();
      state = state.copyWith(decks: decks, isLoading: false);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createDeck(String title, String? description,
      {int? parentId}) async {
    try {
      await _deckService.createDeck(CreateDeck(
          title: title, description: description, parentId: parentId));
      await loadDecks();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteDeck(int id) async {
    try {
      await _deckService.deleteDeck(id);
      await loadDecks();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> renameDeck(int id, String title) async {
    try {
      await _deckService.renameDeck(id, title);
      await loadDecks();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<DeckResponse?> updateDeck(int id,
      {String? title, String? description}) async {
    try {
      final deck = await _deckService.updateDeck(id,
          title: title, description: description);
      await loadDecks();
      return deck;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> duplicateDeck(int id) async {
    try {
      await _deckService.duplicateDeck(id);
      await loadDecks();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> moveDeck(int deckId, {int? parentId}) async {
    try {
      state = state.copyWith(error: null);
      final deck = await _deckService.moveDeck(deckId, parentId);
      final decks = List<DeckResponse>.from(state.decks);
      final idx = decks.indexWhere((d) => d.id == deckId);
      if (idx >= 0) {
        decks[idx] = deck;
      }
      state = state.copyWith(decks: decks);
      await loadDecks();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<DeckDetailResponse?> loadDeckDetail(int id) async {
    try {
      return await _deckService.getDeck(id);
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> shareDeck(int deckId, int userId) async {
    try {
      await _deckService.shareDeck(deckId, userId);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> unshareDeck(int deckId, int userId) async {
    try {
      await _deckService.unshareDeck(deckId, userId);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> transferOwner(int deckId, int userId) async {
    try {
      await _deckService.transferOwner(deckId, userId);
      await loadDecks();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> addDeckToClass(int deckId, int classId) async {
    try {
      await _deckService.addDeckToClass(deckId, classId);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> removeDeckFromClass(int deckId, int classId) async {
    try {
      await _deckService.removeDeckFromClass(deckId, classId);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> loadNoteTypes() async {
    state = state.copyWith(noteTypesLoading: true);

    try {
      final noteTypes = await _deckService.listNoteTypes();
      state = state.copyWith(noteTypes: noteTypes, noteTypesLoading: false);
    } on Exception catch (e) {
      state = state.copyWith(noteTypesLoading: false, error: e.toString());
    }
  }

  Future<bool> createNoteType(CreateNoteType noteType) async {
    try {
      await _deckService.createNoteType(noteType);
      await loadNoteTypes();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteNoteType(int id) async {
    try {
      await _deckService.deleteNoteType(id);
      await loadNoteTypes();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateNoteType(int id, CreateNoteType noteType) async {
    try {
      await _deckService.updateNoteType(id, noteType);
      await loadNoteTypes();
      return true;
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// The shared deck provider.
final deckProvider =
    NotifierProvider<DeckNotifier, DeckState>(DeckNotifier.new);
