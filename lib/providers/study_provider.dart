import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/card_record.dart';
import '../models/common.dart';
import '../models/study.dart';
import '../services/api_client.dart';
import '../services/card_service.dart';
import '../services/study_service.dart';
import '../widgets/safe_notify.dart';
import 'card_store.dart';

class StudyProvider extends ChangeNotifier with SafeNotify {
  final ApiClient _apiClient;
  late CardStore _store;
  late final StudyService _studyService;
  late final CardService _cardService;

  StudyProvider(this._apiClient, this._store) {
    _studyService = StudyService(_apiClient);
    _cardService = CardService(_apiClient);
  }

  set store(CardStore value) => _store = value;

  List<StudyCard> _cards = [];
  int _currentIndex = 0;
  bool _showBack = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  bool _isComplete = false;

  // Metadata
  String? _deckTitle;
  int? _deckId;
  StudySteps? _steps;

  List<StudyCard> get cards => _cards;
  int get currentIndex => _currentIndex;
  bool get showBack => _showBack;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  bool get isComplete => _isComplete;

  StudyCard? get currentCard =>
      _currentIndex < _cards.length ? _cards[_currentIndex] : null;

  String? get deckTitle => _deckTitle;
  int? get deckId => _deckId;
  StudySteps? get steps => _steps;
  int get totalCount => _cards.length;
  int get reviewedCount => _currentIndex;

  /// Counts are delegated to CardStore.
  int get newCount => _store.deckNewCount(_deckId ?? -1);
  int get learningCount => _store.deckLearningCount(_deckId ?? -1);
  int get dueCount => _store.deckDueCount(_deckId ?? -1);

  /// Incremented each time a new fetch loop starts.
  int _loopGeneration = 0;

  void _fetchLoop() async {
    final gen = ++_loopGeneration;
    try {
      while (true) {
        if (gen != _loopGeneration) return;

        // Fetch the current study queue
        _isLoading = true;
        _error = null;
        notifyListeners();

        StudySession session;
        try {
          session = await _studyService.getDeckStudy(_deckId!);
        } on Exception catch (e) {
          _error = e.toString();
          _isLoading = false;
          safeNotify();
          return;
        }

        if (gen != _loopGeneration) return;

        _deckTitle = session.deckTitle ?? 'Study';
        _steps = session.steps;
        _isLoading = false;

        // Filter out cards that aren't actually due yet.
        // New cards (new state) are always due. For review/learning/
        // relearning cards, only include those with due_at <= now.
        final now = DateTime.now();
        final dueCards = session.cards.where((c) {
          if (c.dueAt == null) return true;
          final due = parseTimestamp(c.dueAt);
          return !due.isAfter(now);
        }).toList();
        _cards = dueCards;

        // Upsert full CardRecords so other screens (browser) reflect the
        // authoritative card state immediately.
        _store.upsertCards(session.cards.map(_toRecord));

        // No due cards available — the study session is complete. The backend
        // returns every card in the deck (including future-dated interday
        // learning cards), so this is the real terminal condition; a card may
        // become due again on a later fetch.
        if (_cards.isEmpty) {
          _isComplete = true;
          safeNotify();
          return;
        }

        safeNotify();

        // Review each card in this batch
        for (var i = 0; i < _cards.length; i++) {
          if (gen != _loopGeneration) return;
          _currentIndex = i;
          _showBack = false;
          safeNotify();

          final rated = await _waitForRating();
          _ratingCompleter = null;
          if (gen != _loopGeneration) return;
          if (!rated) return;
        }
      }
    } finally {
      if (gen == _loopGeneration) {
        _isLoading = false;
      }
    }
  }

  Completer<bool>? _ratingCompleter;

  Future<bool> _waitForRating() async {
    _ratingCompleter = Completer<bool>();
    return _ratingCompleter!.future;
  }

  void flipCard() {
    _showBack = !_showBack;
    notifyListeners();
  }

  Future<void> setCardFlag(int cardId, int flag) async {
    try {
      await _studyService.setCardFlag(cardId, flag);
      _store.setCardFlag(cardId, flag);
      final idx = _cards.indexWhere((c) => c.cardId == cardId);
      if (idx >= 0) {
        _cards[idx] = _cards[idx].copyWith(flag: flag);
      }
      notifyListeners();
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Performs a card/note scheduling action and advances past the current card
  /// within the study loop, since the affected card(s) are no longer due.
  ///
  /// Card-level responses (with `suspended`/`buried_until`/`due_at`/`state`)
  /// are applied to the shared [CardStore]; note-level responses (with
  /// `card_ids`) update each affected card.
  Future<void> _applyCardAction(
      Future<Map<String, dynamic>> Function() action) async {
    final card = currentCard;
    if (card == null) return;

    _isSubmitting = true;
    notifyListeners();
    try {
      final response = await action();
      final cardIds = (response['card_ids'] as List? ?? []).cast<int>();
      if (cardIds.isNotEmpty) {
        // Note-level action
        for (final id in cardIds) {
          _store.applyCardMod(
            id,
            suspended: response['suspended'] as int?,
            buriedUntil: response['buried_until'] as int?,
            hasBuriedUntil: response.containsKey('buried_until'),
          );
        }
      } else {
        // Card-level action
        _store.applyCardMod(
          card.cardId,
          suspended: response['suspended'] as int?,
          buriedUntil: response['buried_until'] as int?,
          hasBuriedUntil: response.containsKey('buried_until'),
          dueAt: response['due_at'] as int?,
          state: response['state'] as String?,
        );
      }
      _isSubmitting = false;
      _showBack = false;
      _ratingCompleter?.complete(true);
    } on Exception catch (e) {
      _error = e.toString();
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> suspendCard() => _applyCardAction(
      () async => _cardService.suspendCard(currentCard!.cardId));

  Future<void> buryCard() =>
      _applyCardAction(() async => _cardService.buryCard(currentCard!.cardId));

  Future<void> suspendNote() => _applyCardAction(
      () async => _cardService.suspendNote(currentCard!.noteId!));

  Future<void> buryNote() =>
      _applyCardAction(() async => _cardService.buryNote(currentCard!.noteId!));

  Future<void> rescheduleCard(int days) =>
      _applyCardAction(() async => _cardService.rescheduleCard(
            cardId: currentCard!.cardId,
            days: days,
          ));

  Future<void> submitRating(int rating) async {
    if (currentCard == null) return;

    _isSubmitting = true;
    notifyListeners();

    try {
      final response = await _studyService.submitReview(SubmitReview(
        cardId: currentCard!.cardId,
        rating: rating,
      ));
      _store.applyCardMod(
        currentCard!.cardId,
        state: response.state,
        dueAt: response.dueAt,
      );

      // Update the card in _cards so counts reflect the new state
      final idx = _cards.indexWhere((c) => c.cardId == currentCard!.cardId);
      if (idx >= 0) {
        _cards[idx] = _cards[idx].copyWith(state: response.state);
      }

      _isSubmitting = false;
      safeNotify();
      _ratingCompleter?.complete(true);
    } on Exception catch (e) {
      _error = e.toString();
      _isSubmitting = false;
      safeNotify();
      _ratingCompleter?.complete(false);
    }
  }

  void startDeckStudy(int deckId) {
    _cancelLoop();
    _fullReset();
    _deckId = deckId;
    _fetchLoop();
  }

  void reset() {
    _cancelLoop();
    _fullReset();
    notifyListeners();
  }

  void _cancelLoop() {
    _loopGeneration++;
    if (_ratingCompleter != null && !_ratingCompleter!.isCompleted) {
      _ratingCompleter!.complete(false);
    }
    _ratingCompleter = null;
  }

  void _fullReset() {
    _cards = [];
    _currentIndex = 0;
    _showBack = false;
    _isLoading = false;
    _isSubmitting = false;
    _error = null;
    _isComplete = false;
    _deckTitle = null;
    _deckId = null;
    _steps = null;
  }

  CardRecord _toRecord(StudyCard c) => CardRecord(
        cardId: c.cardId,
        noteId: c.noteId ?? 0,
        deckId: _deckId ?? 0,
        deckTitle: c.deckTitle,
        front: c.front,
        back: c.back,
        noteTypeName: '',
        fields: const {},
        templateIndex: 0,
        state: c.state,
        dueAt: c.dueAt,
        flag: c.flag,
        suspended: _store.isSuspended(c.cardId),
        buriedUntil: _store.buriedUntil(c.cardId),
        newCardPosition: null,
        stability: c.stability,
        difficulty: c.difficulty,
        reps: c.reps,
        lapses: c.lapses,
      );

  @override
  void dispose() {
    _cancelLoop();
    super.dispose();
  }
}
