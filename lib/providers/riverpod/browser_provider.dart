import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/browser_card.dart';
import '../../models/card_record.dart';
import '../../models/note_record.dart';
import '../../services/browser_service.dart';
import '../../services/card_service.dart';
import 'api_client_provider.dart';
import 'card_store_provider.dart';
import 'note_store_provider.dart';

/// Immutable view state for the browser screen.
///
/// This mirrors the mutable fields held by the legacy `BrowserProvider`, but as
/// an immutable value: every state change produces a new [BrowserState].
class BrowserState {
  final List<int> cardIds;
  final bool isLoading;
  final String? error;
  final int page;
  final int total;
  final int perPage;
  final List<int> deckIds;
  final String query;
  final String sort;
  final List<String> states;
  final List<int> noteTypeIds;
  final List<int> flags;

  const BrowserState({
    this.cardIds = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.total = 0,
    this.perPage = 50,
    this.deckIds = const [],
    this.query = '',
    this.sort = 'created_at',
    this.states = const [],
    this.noteTypeIds = const [],
    this.flags = const [],
  });

  /// Whether there is another page after the current one.
  bool get hasNextPage => page * perPage < total;

  /// Whether there is a page before the current one.
  bool get hasPrevPage => page > 1;

  BrowserState copyWith({
    List<int>? cardIds,
    bool? isLoading,
    String? error,
    int? page,
    int? total,
    int? perPage,
    List<int>? deckIds,
    String? query,
    String? sort,
    List<String>? states,
    List<int>? noteTypeIds,
    List<int>? flags,
  }) {
    return BrowserState(
      cardIds: cardIds ?? this.cardIds,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      page: page ?? this.page,
      total: total ?? this.total,
      perPage: perPage ?? this.perPage,
      deckIds: deckIds ?? this.deckIds,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      states: states ?? this.states,
      noteTypeIds: noteTypeIds ?? this.noteTypeIds,
      flags: flags ?? this.flags,
    );
  }
}

/// Riverpod browser store, replacing the legacy `BrowserProvider`.
///
/// Reads the migrated [cardStoreProvider] and [noteStoreProvider] (via
/// `ref.read`) and drives them through [BrowserService]/[CardService].
///
/// NOTE: This is intentionally created but **not yet wired** into `main.dart` or
/// `browser_screen.dart`. It is kept method-compatible with the legacy provider
/// so the screen can swap over in a later migration step.
class BrowserNotifier extends Notifier<BrowserState> {
  @override
  BrowserState build() => const BrowserState();

  BrowserService get _browserService => BrowserService(
        ref.read(apiClientProvider),
      );

  CardService get _cardService => CardService(
        ref.read(apiClientProvider),
      );

  CardStore get _cardStore => ref.read(cardStoreProvider.notifier);
  NoteStore get _noteStore => ref.read(noteStoreProvider.notifier);

  /// Resolves [cardIds] against the [cardStoreProvider] into full records.
  List<CardRecord> get cards => state.cardIds
      .map((id) => _cardStore.card(id))
      .whereType<CardRecord>()
      .toList();

  Future<void> loadCards({bool append = false}) async {
    if (!append) {
      state = state.copyWith(isLoading: true);
    }
    state = state.copyWith(error: null);

    try {
      final current = state;
      final response = await _browserService.browseCards(
        deckIds: current.deckIds.isEmpty ? null : current.deckIds,
        query: current.query,
        sort: current.sort,
        page: current.page,
        perPage: current.perPage,
        states: current.states.isEmpty ? null : current.states,
        noteTypeIds: current.noteTypeIds.isEmpty ? null : current.noteTypeIds,
        flags: current.flags.isEmpty ? null : current.flags,
      );

      final newCardIds = [
        if (append) ...current.cardIds,
        ...response.cards.map((c) => c.cardId),
      ];

      state = state.copyWith(
        cardIds: newCardIds,
        total: response.total,
      );

      // Upsert full CardRecords into the store so columns (state/flag/etc.)
      // reflect the current authoritative state.
      _cardStore.upsertCards(response.cards.map(_toRecord));

      // Upsert derived NoteRecords into the note store.
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
      state = state.copyWith(error: e.toString());
    }

    state = state.copyWith(isLoading: false);
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
        templateName: c.templateName,
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
    final ids = List<int>.of(state.deckIds);
    if (ids.contains(deckId)) {
      ids.remove(deckId);
    } else {
      ids.add(deckId);
    }
    state = state.copyWith(deckIds: ids, page: 1);
    loadCards();
  }

  void setDeckIds(List<int> deckIds) {
    state = state.copyWith(deckIds: List.of(deckIds), page: 1);
    loadCards();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query, page: 1);
    loadCards();
  }

  void setSort(String sort) {
    state = state.copyWith(sort: sort, page: 1);
    loadCards();
  }

  void toggleState(String value) {
    final values = List<String>.of(state.states);
    if (values.contains(value)) {
      values.remove(value);
    } else {
      values.add(value);
    }
    state = state.copyWith(states: values, page: 1);
    loadCards();
  }

  void setStates(List<String> values) {
    state = state.copyWith(states: List.of(values), page: 1);
    loadCards();
  }

  void toggleNoteTypeId(int noteTypeId) {
    final ids = List<int>.of(state.noteTypeIds);
    if (ids.contains(noteTypeId)) {
      ids.remove(noteTypeId);
    } else {
      ids.add(noteTypeId);
    }
    state = state.copyWith(noteTypeIds: ids, page: 1);
    loadCards();
  }

  void setNoteTypeIds(List<int> noteTypeIds) {
    state = state.copyWith(noteTypeIds: List.of(noteTypeIds), page: 1);
    loadCards();
  }

  void setFlags(List<int> flags) {
    state = state.copyWith(flags: List.of(flags), page: 1);
    loadCards();
  }

  void setFilters({
    List<int>? deckIds,
    List<String>? states,
    List<int>? noteTypeIds,
    List<int>? flags,
  }) {
    state = state.copyWith(
      deckIds: deckIds == null ? state.deckIds : List.of(deckIds),
      states: states == null ? state.states : List.of(states),
      noteTypeIds:
          noteTypeIds == null ? state.noteTypeIds : List.of(noteTypeIds),
      flags: flags == null ? state.flags : List.of(flags),
      page: 1,
    );
    loadCards();
  }

  Future<void> nextPage() async {
    if (state.hasNextPage) {
      state = state.copyWith(page: state.page + 1);
      await loadCards(append: true);
    }
  }

  Future<void> prevPage() async {
    if (state.hasPrevPage) {
      state = state.copyWith(page: state.page - 1);
      await loadCards();
    }
  }

  void updateCardFlag(int cardId, int flag) {
    _cardStore.setCardFlag(cardId, flag);
  }

  Future<void> _applyCardState(
      int cardId, Future<Map<String, dynamic>> Function() action) async {
    try {
      final response = await action();
      await loadCards();
      _cardStore.applyCardMod(
        cardId,
        suspended: response['suspended'] as int?,
        buriedUntil: response['buried_until'] as int?,
        hasBuriedUntil: response.containsKey('buried_until'),
        dueAt: response['due_at'] as int?,
        state: response['state'] as String?,
      );
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
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
        _cardStore.applyCardMod(
          id,
          suspended: suspended,
          buriedUntil: buriedUntil,
          hasBuriedUntil: hasBuriedUntil,
        );
      }
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> suspendNote(int noteId) =>
      _applyNoteAction(() async => _cardService.suspendNote(noteId));

  Future<void> unsuspendNote(int noteId) =>
      _applyNoteAction(() async => _cardService.unsuspendNote(noteId));

  Future<void> buryNote(int noteId) =>
      _applyNoteAction(() async => _cardService.buryNote(noteId));

  Future<void> unburyNote(int noteId) =>
      _applyNoteAction(() async => _cardService.unburyNote(noteId));
}

final browserProvider =
    NotifierProvider<BrowserNotifier, BrowserState>(BrowserNotifier.new);
