import 'package:flutter/foundation.dart';
import '../models/browser_card.dart';
import '../models/card_record.dart';
import '../models/note_record.dart';
import '../services/api_client.dart';
import '../services/browser_service.dart';
import '../services/card_service.dart';
import '../widgets/safe_notify.dart';
import 'card_store.dart';
import 'note_store.dart';

class BrowserProvider extends ChangeNotifier with SafeNotify {
  final ApiClient _apiClient;
  late CardStore _store;
  late NoteStore _noteStore;
  late final BrowserService _browserService;
  late final CardService _cardService;

  BrowserProvider(this._apiClient, this._store, this._noteStore) {
    _browserService = BrowserService(_apiClient);
    _cardService = CardService(_apiClient);
  }

  set store(CardStore value) => _store = value;
  set noteStore(NoteStore value) => _noteStore = value;

  List<int> _cardIds = [];
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

  List<CardRecord> get cards =>
      _cardIds.map((id) => _store.card(id)).whereType<CardRecord>().toList();
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
        _cardIds = [..._cardIds, ...response.cards.map((c) => c.cardId)];
      } else {
        _cardIds = response.cards.map((c) => c.cardId).toList();
      }
      _total = response.total;

      // Upsert full CardRecords into the store so screens that read the store
      // (e.g. Due/State/Flag columns) reflect the current authoritative state.
      _store.upsertCards(response.cards.map(_toRecord));

      // Upsert derived NoteRecords into NoteStore so the Notes tab and note
      // details are driven from the same single source of truth as cards.
      final notesById = <int, NoteRecord>{};
      for (final c in response.cards) {
        final note = notesById[c.noteId];
        if (note == null) {
          notesById[c.noteId] = NoteRecord(
            noteId: c.noteId,
            noteTypeId: c.noteTypeId,
            noteTypeName: c.noteTypeName,
            fields: c.fields,
            cardIds: [c.cardId],
          );
        } else {
          notesById[c.noteId] = note.copyWith(
            cardIds: [...note.cardIds, c.cardId],
          );
        }
      }
      _noteStore.upsertNotes(notesById.values);
    } on Exception catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    safeNotify();
  }

  CardRecord _toRecord(BrowserCard c) => CardRecord(
        cardId: c.cardId,
        noteId: c.noteId,
        deckId: c.deckId,
        deckTitle: c.deckTitle,
        front: c.front,
        back: c.back,
        noteTypeName: c.noteTypeName,
        fields: c.fields,
        templateIndex: c.templateIndex,
        state: c.state,
        dueAt: c.dueAt,
        flag: c.flag,
        suspended: c.suspended == 1,
        buriedUntil: c.buriedUntil,
        newCardPosition: c.newCardPosition,
        stability: c.stability,
        difficulty: c.difficulty,
        reps: c.reps,
        lapses: c.lapses,
        createdAt: c.createdAt,
      );

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
    _store.setCardFlag(cardId, flag);
    notifyListeners();
  }

  /// Applies a card-level scheduling response to the shared CardStore
  /// so other screens (e.g. study) immediately reflect the new state.
  Future<void> _applyCardState(
      int cardId, Future<Map<String, dynamic>> Function() action) async {
    try {
      final response = await action();
      // Reload first so the browse list refreshes, then apply the action's
      // authoritative response last (it wins over the possibly-stale browse
      // snapshot).
      await loadCards();
      _store.applyCardMod(
        cardId,
        suspended: response['suspended'] as int?,
        buriedUntil: response['buried_until'] as int?,
        hasBuriedUntil: response.containsKey('buried_until'),
        dueAt: response['due_at'] as int?,
        state: response['state'] as String?,
      );
    } on Exception catch (e) {
      _error = e.toString();
      safeNotify();
    }
  }

  Future<void> suspendCard(int cardId) =>
      _applyCardState(cardId, () async => _cardService.suspendCard(cardId));

  Future<void> unsuspendCard(int cardId) =>
      _applyCardState(cardId, () async => _cardService.unsuspendCard(cardId));

  Future<void> buryCard(int cardId) =>
      _applyCardState(cardId, () async => _cardService.buryCard(cardId));

  Future<void> unburyCard(int cardId) =>
      _applyCardState(cardId, () async => _cardService.unburyCard(cardId));

  Future<void> rescheduleCard(int cardId, int days) => _applyCardState(cardId,
      () async => _cardService.rescheduleCard(cardId: cardId, days: days));

  /// Applies a note-level action (NoteModResponse with `card_ids`) to the
  /// store, then reloads.
  Future<void> _applyNoteAction(
      Future<Map<String, dynamic>> Function() action) async {
    try {
      final response = await action();
      final cardIds = (response['card_ids'] as List? ?? []).cast<int>();
      final suspended = response['suspended'] as int?;
      final buriedUntil = response['buried_until'] as int?;
      final hasBuriedUntil = response.containsKey('buried_until');
      await loadCards();
      for (final id in cardIds) {
        _store.applyCardMod(
          id,
          suspended: suspended,
          buriedUntil: buriedUntil,
          hasBuriedUntil: hasBuriedUntil,
        );
      }
    } on Exception catch (e) {
      _error = e.toString();
      safeNotify();
    }
  }

  Future<void> suspendNote(int noteId) =>
      _applyNoteAction(() async => _cardService.suspendNote(noteId));

  Future<void> buryNote(int noteId) =>
      _applyNoteAction(() async => _cardService.buryNote(noteId));
}
