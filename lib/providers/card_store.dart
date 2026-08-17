import 'package:flutter/foundation.dart';
import '../models/card_record.dart';
import '../models/note_record.dart';
import '../widgets/safe_notify.dart';

/// Single source of truth for all cards and notes.
///
/// Screens read from this store and every mutation (from study, browser, or
/// deck screens) writes through it, so a change made anywhere propagates
/// everywhere without each provider re-fetching its own copy.
class CardStore extends ChangeNotifier with SafeNotify {
  /// cardId → full card record.
  final Map<int, CardRecord> _cards = {};

  /// noteId → full note record.
  final Map<int, NoteRecord> _notes = {};

  // ── Card reads ──────────────────────────────────────────────────────────

  CardRecord? card(int cardId) => _cards[cardId];

  List<CardRecord> get allCards => _cards.values.toList();

  List<CardRecord> cardsByDeck(int deckId) =>
      _cards.values.where((c) => c.deckId == deckId).toList();

  List<CardRecord> cardsByNote(int noteId) =>
      _cards.values.where((c) => c.noteId == noteId).toList();

  // ── Note reads ──────────────────────────────────────────────────────────

  NoteRecord? note(int noteId) => _notes[noteId];

  // ── Card writes ─────────────────────────────────────────────────────────

  void upsertCard(CardRecord card) {
    _cards[card.cardId] = card;
    notifyListeners();
  }

  void upsertCards(Iterable<CardRecord> cards) {
    for (final c in cards) {
      _cards[c.cardId] = c;
    }
    notifyListeners();
  }

  void removeCard(int cardId) {
    _cards.remove(cardId);
    notifyListeners();
  }

  // ── Note writes ─────────────────────────────────────────────────────────

  void upsertNote(NoteRecord note) {
    _notes[note.noteId] = note;
    notifyListeners();
  }

  void removeNote(int noteId) {
    _notes.remove(noteId);
    notifyListeners();
  }

  // ── Derived / convenience reads ─────────────────────────────────────────

  String? cardState(int cardId) => _cards[cardId]?.state;

  int? cardFlag(int cardId) => _cards[cardId]?.flag;

  bool isSuspended(int cardId) => _cards[cardId]?.suspended ?? false;

  int? buriedUntil(int cardId) => _cards[cardId]?.buriedUntil;

  bool isBuried(int cardId) => _cards[cardId]?.buriedUntil != null;

  // ── Targeted mutations (operate on full records) ────────────────────────

  /// Sets review state for a card. Creates a minimal record if not present.
  void setCardState(int cardId, int deckId, String state) {
    final existing = _cards[cardId];
    _cards[cardId] = (existing ?? _minimalCard(cardId, deckId)).copyWith(
      state: state,
    );
    notifyListeners();
  }

  void setCardFlag(int cardId, int flag) {
    final existing = _cards[cardId];
    if (existing == null) return;
    _cards[cardId] = existing.copyWith(flag: flag);
    notifyListeners();
  }

  void setSchedulingState(int cardId, {int? suspended, int? buriedUntil}) {
    final existing = _cards[cardId];
    if (existing == null) return;
    _cards[cardId] = existing.copyWith(
      suspended: suspended == 1,
      buriedUntil: buriedUntil,
    );
    notifyListeners();
  }

  void setDueAt(int cardId, int? dueAt) {
    final existing = _cards[cardId];
    if (existing == null) return;
    _cards[cardId] = existing.copyWith(dueAt: dueAt);
    notifyListeners();
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
    final existing = _cards[cardId];
    if (existing == null) return;
    _cards[cardId] = CardRecord(
      cardId: existing.cardId,
      noteId: existing.noteId,
      deckId: existing.deckId,
      deckTitle: existing.deckTitle,
      front: existing.front,
      back: existing.back,
      noteTypeName: existing.noteTypeName,
      fields: existing.fields,
      templateIndex: existing.templateIndex,
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
    );
    notifyListeners();
  }

  /// Seeds review state for a batch of study cards (StudyProvider → store).
  void seedFromStudyCards(
      int deckId, Iterable<({int cardId, String state})> cards) {
    for (final c in cards) {
      final existing = _cards[c.cardId];
      _cards[c.cardId] =
          (existing ?? _minimalCard(c.cardId, deckId)).copyWith(state: c.state);
    }
    notifyListeners();
  }

  /// Seeds suspend/bury state for a batch of browse cards.
  void seedSchedulingState(
      Iterable<({int cardId, int? suspended, int? buriedUntil})> cards) {
    for (final c in cards) {
      final existing = _cards[c.cardId];
      if (existing == null) continue;
      _cards[c.cardId] = existing.copyWith(
        suspended: c.suspended == 1,
        buriedUntil: c.buriedUntil,
      );
    }
    notifyListeners();
  }

  // ── Per-deck counts ─────────────────────────────────────────────────────

  int deckNewCount(int deckId) =>
      _cards.values.where((c) => c.deckId == deckId && c.state == 'new').length;

  int deckLearningCount(int deckId) => _cards.values
      .where((c) =>
          c.deckId == deckId &&
          (c.state == 'learning' || c.state == 'relearning'))
      .length;

  int deckDueCount(int deckId) => _cards.values
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
  void clear() {
    _cards.clear();
    _notes.clear();
    notifyListeners();
  }
}
