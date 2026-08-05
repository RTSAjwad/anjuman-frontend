import 'package:flutter/foundation.dart';
import '../models/browser_card.dart';
import '../services/api_client.dart';
import '../services/browser_service.dart';
import '../widgets/safe_notify.dart';

class BrowserProvider extends ChangeNotifier with SafeNotify {
  final ApiClient _apiClient;
  late final BrowserService _browserService;

  BrowserProvider(this._apiClient) {
    _browserService = BrowserService(_apiClient);
  }

  List<BrowserCard> _cards = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  final int _perPage = 50;

  List<int> _deckIds = [];
  String _query = '';
  String _sort = 'created_at';
  List<String> _states = [];
  List<int> _noteTypeIds = [];
  List<int> _flags = [];

  List<BrowserCard> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get page => _page;
  int get total => _total;
  int get perPage => _perPage;
  List<int> get deckIds => _deckIds;
  String get query => _query;
  String get sort => _sort;
  List<String> get states => _states;
  List<int> get noteTypeIds => _noteTypeIds;
  List<int> get flags => _flags;

  bool get hasNextPage => _page * _perPage < _total;
  bool get hasPrevPage => _page > 1;

  Future<void> loadCards({bool append = false}) async {
    if (!append) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final response = await _browserService.browseCards(
        deckIds: _deckIds.isEmpty ? null : _deckIds,
        query: _query,
        sort: _sort,
        page: _page,
        perPage: _perPage,
        states: _states.isEmpty ? null : _states,
        noteTypeIds: _noteTypeIds.isEmpty ? null : _noteTypeIds,
        flags: _flags.isEmpty ? null : _flags,
      );
      if (append) {
        _cards = [..._cards, ...response.cards];
      } else {
        _cards = response.cards;
      }
      _total = response.total;
    } on Exception catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    safeNotify();
  }

  void toggleDeckId(int deckId) {
    if (_deckIds.contains(deckId)) {
      _deckIds.remove(deckId);
    } else {
      _deckIds.add(deckId);
    }
    _page = 1;
    loadCards();
  }

  void setDeckIds(List<int> deckIds) {
    _deckIds = List.of(deckIds);
    _page = 1;
    loadCards();
  }

  void setQuery(String query) {
    _query = query;
    _page = 1;
    loadCards();
  }

  void setSort(String sort) {
    _sort = sort;
    _page = 1;
    loadCards();
  }

  void toggleState(String state) {
    if (_states.contains(state)) {
      _states.remove(state);
    } else {
      _states.add(state);
    }
    _page = 1;
    loadCards();
  }

  void setStates(List<String> states) {
    _states = List.of(states);
    _page = 1;
    loadCards();
  }

  void toggleNoteTypeId(int noteTypeId) {
    if (_noteTypeIds.contains(noteTypeId)) {
      _noteTypeIds.remove(noteTypeId);
    } else {
      _noteTypeIds.add(noteTypeId);
    }
    _page = 1;
    loadCards();
  }

  void setNoteTypeIds(List<int> noteTypeIds) {
    _noteTypeIds = List.of(noteTypeIds);
    _page = 1;
    loadCards();
  }

  void setFlags(List<int> flags) {
    _flags = List.of(flags);
    _page = 1;
    loadCards();
  }

  void setFilters({
    List<int>? deckIds,
    List<String>? states,
    List<int>? noteTypeIds,
    List<int>? flags,
  }) {
    if (deckIds != null) _deckIds = List.of(deckIds);
    if (states != null) _states = List.of(states);
    if (noteTypeIds != null) _noteTypeIds = List.of(noteTypeIds);
    if (flags != null) _flags = List.of(flags);
    _page = 1;
    loadCards();
  }

  Future<void> nextPage() async {
    if (hasNextPage) {
      _page++;
      await loadCards(append: true);
    }
  }

  Future<void> prevPage() async {
    if (hasPrevPage) {
      _page--;
      await loadCards();
    }
  }

  void updateCardFlag(int cardId, int flag) {
    final idx = _cards.indexWhere((c) => c.cardId == cardId);
    if (idx >= 0) {
      _cards[idx] = BrowserCard(
        cardId: _cards[idx].cardId,
        noteId: _cards[idx].noteId,
        deckId: _cards[idx].deckId,
        deckTitle: _cards[idx].deckTitle,
        templateIndex: _cards[idx].templateIndex,
        front: _cards[idx].front,
        back: _cards[idx].back,
        noteTypeName: _cards[idx].noteTypeName,
        fields: _cards[idx].fields,
        state: _cards[idx].state,
        dueAt: _cards[idx].dueAt,
        stability: _cards[idx].stability,
        difficulty: _cards[idx].difficulty,
        reps: _cards[idx].reps,
        lapses: _cards[idx].lapses,
        createdAt: _cards[idx].createdAt,
        newCardPosition: _cards[idx].newCardPosition,
        flag: flag,
      );
      notifyListeners();
    }
  }
}
