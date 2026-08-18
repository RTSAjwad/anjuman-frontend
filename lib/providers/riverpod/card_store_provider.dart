import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card_record.dart';
import 'deck_counts_provider.dart';

/// Riverpod single source of truth for all cards.
///
/// State is an immutable `Map<int, CardRecord>` (cardId → full record). Every
/// mutation replaces the map via `state = {...state, ...}`, so watchers are
/// notified and reads stay consistent.
///
/// This store has no knowledge of notes. Note scheduling flags are derived
/// from card state in `note_scheduling_provider.dart`.
class CardStore extends Notifier<Map<int, CardRecord>> {
  @override
  Map<int, CardRecord> build() => {};

  // ── Card reads ──────────────────────────────────────────────────────────

  CardRecord? card(int cardId) => state[cardId];

  List<CardRecord> get allCards => state.values.toList();

  List<CardRecord> cardsByDeck(int deckId) =>
      state.values.where((c) => c.deckId == deckId).toList();

  List<CardRecord> cardsByNote(int noteId) =>
      state.values.where((c) => c.noteId == noteId).toList();

  // ── Card writes ─────────────────────────────────────────────────────────

  void upsertCard(CardRecord card) {
    state = {...state, card.cardId: card};
  }

  void upsertCards(Iterable<CardRecord> cards) {
    final map = {...state};
    for (final c in cards) {
      map[c.cardId] = c;
    }
    state = map;
  }

  void removeCard(int cardId) {
    state = {...state}..remove(cardId);
    _invalidateCounts();
  }

  /// Invalidates the derived deck-counts provider so the deck list re-fetches
  /// fresh counts after a scheduling-relevant card mutation.
  void _invalidateCounts() => ref.invalidate(deckCountsProvider);

  // ── Derived / convenience reads ─────────────────────────────────────────

  String? cardState(int cardId) => state[cardId]?.state;

  int? cardFlag(int cardId) => state[cardId]?.flag;

  bool isSuspended(int cardId) => state[cardId]?.suspended ?? false;

  int? buriedUntil(int cardId) => state[cardId]?.buriedUntil;

  bool isBuried(int cardId) => state[cardId]?.isBuried ?? false;

  // ── Targeted mutations (operate on full records) ────────────────────────

  /// Sets review state for a card. Creates a minimal record if not present.
  void setCardState(int cardId, int deckId, String newState) {
    final existing = state[cardId];
    state = {
      ...state,
      cardId:
          (existing ?? _minimalCard(cardId, deckId)).copyWith(state: newState),
    };
    _invalidateCounts();
  }

  void setCardFlag(int cardId, int flag) {
    final existing = state[cardId];
    if (existing == null) return;
    state = {...state, cardId: existing.copyWith(flag: flag)};
  }

  void setSchedulingState(int cardId, {int? suspended, int? buriedUntil}) {
    final existing = state[cardId];
    if (existing == null) return;
    state = {
      ...state,
      cardId: existing.copyWith(
        suspended: suspended == 1,
        buriedUntil: buriedUntil,
      ),
    };
    _invalidateCounts();
  }

  void setDueAt(int cardId, int? dueAt) {
    final existing = state[cardId];
    if (existing == null) return;
    state = {...state, cardId: existing.copyWith(dueAt: dueAt)};
    _invalidateCounts();
  }

  /// Applies fields from a card modification response (CardModResponse).
  /// `suspended` is 1/0. `hasBuriedUntil` marks whether `buriedUntil` is
  /// authoritative (true even when null, e.g. an unbury clears it).
  void applyCardMod(
    int cardId, {
    int? suspended,
    int? buriedUntil,
    bool hasBuriedUntil = false,
    int? dueAt,
    String? state,
  }) {
    final existing = this.state[cardId];
    if (existing == null) return;
    this.state = {
      ...this.state,
      cardId: CardRecord(
        cardId: existing.cardId,
        noteId: existing.noteId,
        deckId: existing.deckId,
        deckTitle: existing.deckTitle,
        front: existing.front,
        back: existing.back,
        noteTypeName: existing.noteTypeName,
        fields: existing.fields,
        templateIndex: existing.templateIndex,
        templateName: existing.templateName,
        state: state ?? existing.state,
        dueAt: dueAt ?? existing.dueAt,
        flag: existing.flag,
        suspended: suspended == null ? existing.suspended : suspended == 1,
        buriedUntil: hasBuriedUntil ? buriedUntil : existing.buriedUntil,
        newCardPosition: existing.newCardPosition,
        stability: existing.stability,
        difficulty: existing.difficulty,
        reps: existing.reps,
        lapses: existing.lapses,
        predictedInterval: existing.predictedInterval,
        stepIndex: existing.stepIndex,
        createdAt: existing.createdAt,
      ),
    };
    _invalidateCounts();
  }

  /// Seeds review state for a batch of study cards.
  void seedFromStudyCards(
      int deckId, Iterable<({int cardId, String state})> cards) {
    final map = {...state};
    for (final c in cards) {
      final existing = state[c.cardId];
      map[c.cardId] =
          (existing ?? _minimalCard(c.cardId, deckId)).copyWith(state: c.state);
    }
    state = map;
  }

  /// Seeds suspend/bury state for a batch of browse cards.
  void seedSchedulingState(
      Iterable<({int cardId, int? suspended, int? buriedUntil})> cards) {
    final map = {...state};
    for (final c in cards) {
      final existing = state[c.cardId];
      if (existing == null) continue;
      map[c.cardId] = existing.copyWith(
        suspended: c.suspended == 1,
        buriedUntil: c.buriedUntil,
      );
    }
    state = map;
    _invalidateCounts();
  }

  // ── Per-deck counts ─────────────────────────────────────────────────────

  int deckNewCount(int deckId) =>
      state.values.where((c) => c.deckId == deckId && c.state == 'new').length;

  int deckLearningCount(int deckId) => state.values
      .where((c) =>
          c.deckId == deckId &&
          (c.state == 'learning' || c.state == 'relearning'))
      .length;

  int deckDueCount(int deckId) => state.values
      .where((c) => c.deckId == deckId && c.state == 'review')
      .length;

  // ── Internals / reset ───────────────────────────────────────────────────

  CardRecord _minimalCard(int cardId, int deckId) => CardRecord(
        cardId: cardId,
        noteId: 0,
        deckId: deckId,
        deckTitle: '',
        front: '',
        back: '',
        noteTypeName: '',
        fields: const {},
        templateIndex: 0,
        stability: 0,
        difficulty: 0,
        reps: 0,
        lapses: 0,
      );

  /// Clear all tracked state (e.g. on logout).
  void clear() => state = {};
}

/// The shared card store provider.
final cardStoreProvider =
    NotifierProvider<CardStore, Map<int, CardRecord>>(CardStore.new);
