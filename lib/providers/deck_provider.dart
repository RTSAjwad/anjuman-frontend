import 'package:flutter/foundation.dart';
import '../models/common.dart';
import '../models/deck.dart';
import '../services/api_client.dart';
import '../services/deck_service.dart';
import '../widgets/safe_notify.dart';

class DeckProvider extends ChangeNotifier with SafeNotify {
  final ApiClient _apiClient;
  late final DeckService _deckService;

  ApiClient get apiClient => _apiClient;

  DeckProvider(this._apiClient) {
    _deckService = DeckService(_apiClient);
  }

  List<DeckResponse> _decks = [];
  bool _isLoading = false;
  String? _error;

  List<DeckResponse> get decks => _decks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDecks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _decks = await _deckService.listDecks();
    } on Exception catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createDeck(String title, String? description,
      {int? parentId}) async {
    try {
      await _deckService.createDeck(CreateDeck(
          title: title, description: description, parentId: parentId));
      await loadDecks();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDeck(int id) async {
    try {
      await _deckService.deleteDeck(id);
      await loadDecks();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameDeck(int id, String title) async {
    try {
      await _deckService.renameDeck(id, title);
      await loadDecks();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
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
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> duplicateDeck(int id) async {
    try {
      await _deckService.duplicateDeck(id);
      await loadDecks();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> moveDeck(int deckId, {int? parentId}) async {
    try {
      _error = null;
      final deck = await _deckService.moveDeck(deckId, parentId);
      // Update the moved deck in-place before full reload
      final idx = _decks.indexWhere((d) => d.id == deckId);
      if (idx >= 0) {
        _decks[idx] = deck;
      }
      await loadDecks();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<DeckDetailResponse?> loadDeckDetail(int id) async {
    try {
      return await _deckService.getDeck(id);
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> shareDeck(int deckId, int userId) async {
    try {
      await _deckService.shareDeck(deckId, userId);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unshareDeck(int deckId, int userId) async {
    try {
      await _deckService.unshareDeck(deckId, userId);
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> transferOwner(int deckId, int userId) async {
    try {
      await _deckService.transferOwner(deckId, userId);
      await loadDecks();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addDeckToClass(int deckId, int classId) async {
    try {
      await _deckService.addDeckToClass(deckId, classId);
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeDeckFromClass(int deckId, int classId) async {
    try {
      await _deckService.removeDeckFromClass(deckId, classId);
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Note Types

  List<NoteType> _noteTypes = [];
  bool _noteTypesLoading = false;

  List<NoteType> get noteTypes => _noteTypes;
  bool get noteTypesLoading => _noteTypesLoading;

  Future<void> loadNoteTypes() async {
    _noteTypesLoading = true;
    notifyListeners();

    try {
      _noteTypes = await _deckService.listNoteTypes();
    } on Exception catch (e) {
      _error = e.toString();
    }

    _noteTypesLoading = false;
    safeNotify();
  }

  Future<bool> createNoteType(CreateNoteType noteType) async {
    try {
      await _deckService.createNoteType(noteType);
      await loadNoteTypes();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteNoteType(int id) async {
    try {
      await _deckService.deleteNoteType(id);
      await loadNoteTypes();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateNoteType(int id, CreateNoteType noteType) async {
    try {
      await _deckService.updateNoteType(id, noteType);
      await loadNoteTypes();
      return true;
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
