import 'package:flutter/foundation.dart';
import '../widgets/safe_notify.dart';

/// Single source of truth for per-card state metadata shared across screens.
///
/// Tracks card review states (new/learning/review/relearning) and flags
/// independently of the study queue, browser pagination, or deck list.
class CardStateProvider extends ChangeNotifier with SafeNotify {
  /// cardId → review state (new, learning, review, relearning)
  final Map<int, String> _cardStates = {};

  /// cardId → flag (0-7, 0 = no flag)
  final Map<int, int> _cardFlags = {};

  /// cardId → deckId (needed so we can compute per-deck counts)
  final Map<int, int> _cardDecks = {};

  // ── Card state ──────────────────────────────────────────────────────────

  String? cardState(int cardId) => _cardStates[cardId];

  void setCardState(int cardId, int deckId, String state) {
    _cardStates[cardId] = state;
    _cardDecks[cardId] = deckId;
    notifyListeners();
  }

  void seedFromStudyCards(
      int deckId, Iterable<({int cardId, String state})> cards) {
    for (final c in cards) {
      _cardStates[c.cardId] = c.state;
      _cardDecks[c.cardId] = deckId;
    }
    notifyListeners();
  }

  // ── Per‑deck counts ─────────────────────────────────────────────────────

  int deckNewCount(int deckId) => _cardDecks.entries
      .where((e) => e.value == deckId && _cardStates[e.key] == 'new')
      .length;

  int deckLearningCount(int deckId) => _cardDecks.entries
      .where((e) =>
          e.value == deckId &&
          (_cardStates[e.key] == 'learning' ||
              _cardStates[e.key] == 'relearning'))
      .length;

  int deckDueCount(int deckId) => _cardDecks.entries
      .where((e) => e.value == deckId && _cardStates[e.key] == 'review')
      .length;

  // ── Flag ────────────────────────────────────────────────────────────────

  int? cardFlag(int cardId) => _cardFlags[cardId];

  void setCardFlag(int cardId, int flag) {
    _cardFlags[cardId] = flag;
    notifyListeners();
  }

  // ── Reset ───────────────────────────────────────────────────────────────

  /// Clear all tracked state (e.g. on logout).
  void clear() {
    _cardStates.clear();
    _cardFlags.clear();
    _cardDecks.clear();
    notifyListeners();
  }
}
